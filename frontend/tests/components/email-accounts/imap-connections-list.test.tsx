import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import { ImapConnectionsList } from '@/components/email-accounts/imap-connections-list';

describe('ImapConnectionsList', () => {
  it('shows empty message when API returns no connections', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => ({ connections: [] }),
      })
    );

    render(<ImapConnectionsList accountId="1" apiBaseUrl="http://localhost:3001" refreshKey={0} />);

    await waitFor(() => {
      expect(screen.getByText(/no imap accounts connected yet/i)).toBeInTheDocument();
    });

    expect(fetch).toHaveBeenCalledWith('http://localhost:3001/accounts/1/imap/connections', {
      credentials: 'include',
      cache: 'no-store',
    });
  });

  it('lists connections from the API', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => ({
          connections: [
            {
              id: 2,
              host: 'imap.example.com',
              port: 993,
              ssl: true,
              username: 'user@example.com',
              inbox_folder: 'INBOX',
              last_synced_uid: null,
              active: true,
              created_at: '2026-01-01T00:00:00.000Z',
              updated_at: '2026-01-01T00:00:00.000Z',
            },
          ],
        }),
      })
    );

    render(<ImapConnectionsList accountId="1" apiBaseUrl="http://localhost:3001" refreshKey={0} />);

    await waitFor(() => {
      expect(screen.getByText('user@example.com')).toBeInTheDocument();
    });

    expect(screen.getByText(/imap\.example\.com:993/i)).toBeInTheDocument();
    expect(screen.getByText(/active/i)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /sync now for user@example\.com/i })).toBeInTheDocument();
  });

  it('sync button POSTs to sync endpoint and reloads list', async () => {
    const connection = {
      id: 5,
      host: 'imap.example.com',
      port: 993,
      ssl: true,
      username: 'sync@example.com',
      inbox_folder: 'INBOX',
      last_synced_uid: null,
      active: true,
      created_at: '',
      updated_at: '',
    };
    const fetchMock = vi
      .fn()
      // initial load
      .mockResolvedValueOnce({ ok: true, json: async () => ({ connections: [connection] }) })
      // POST sync
      .mockResolvedValueOnce({ ok: true, json: async () => ({}) })
      // reload after sync
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({ connections: [{ ...connection, last_synced_uid: 10 }] }),
      });
    vi.stubGlobal('fetch', fetchMock);

    render(<ImapConnectionsList accountId="1" apiBaseUrl="http://localhost:3001" refreshKey={0} />);

    await waitFor(() => {
      expect(screen.getByText('sync@example.com')).toBeInTheDocument();
    });

    fireEvent.click(screen.getByRole('button', { name: /sync now for sync@example\.com/i }));

    await waitFor(() => {
      expect(fetchMock).toHaveBeenCalledWith('http://localhost:3001/accounts/1/imap/connections/5/sync', {
        method: 'POST',
        credentials: 'include',
        cache: 'no-store',
      });
    });

    await waitFor(() => {
      expect(screen.getByText(/last synced uid: 10/i)).toBeInTheDocument();
    });
  });

  it('refetches when refreshKey changes', async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ connections: [] }),
    });
    vi.stubGlobal('fetch', fetchMock);

    const { rerender } = render(
      <ImapConnectionsList accountId="1" apiBaseUrl="http://localhost:3001" refreshKey={0} />
    );

    await waitFor(() => expect(fetchMock).toHaveBeenCalledTimes(1));

    rerender(<ImapConnectionsList accountId="1" apiBaseUrl="http://localhost:3001" refreshKey={1} />);

    await waitFor(() => expect(fetchMock).toHaveBeenCalledTimes(2));
  });

  it('shows error and retries on demand', async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce({
        ok: false,
        status: 500,
        json: async () => ({}),
      })
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          connections: [
            {
              id: 1,
              host: 'imap.test',
              port: 993,
              ssl: true,
              username: 'a@test',
              inbox_folder: 'INBOX',
              last_synced_uid: null,
              active: true,
              created_at: '',
              updated_at: '',
            },
          ],
        }),
      });
    vi.stubGlobal('fetch', fetchMock);

    render(<ImapConnectionsList accountId="1" apiBaseUrl="http://localhost:3001" refreshKey={0} />);

    await waitFor(() => {
      expect(screen.getByRole('alert')).toHaveTextContent(/could not load accounts/i);
    });

    fireEvent.click(screen.getByRole('button', { name: /retry/i }));

    await waitFor(() => {
      expect(screen.getByText('a@test')).toBeInTheDocument();
    });
  });
});
