'use client';

import { useState, useRef, useEffect } from 'react';
import Link from 'next/link';
import { browserToasterApiBase } from '@/lib/toaster-api';
import { toasterFetch } from '@/lib/toaster-fetch';

type Item = { href: string; label: string };

const LOGGED_OUT_ITEMS: Item[] = [{ href: '/login', label: 'Log in' }];

const LOGGED_IN_ITEMS: Item[] = [
  { href: '/inbox', label: 'Operator inbox' },
  { href: '/email-accounts', label: 'Email accounts' },
  { href: '/settings', label: 'Settings' },
];

export function HamburgerMenu({ isAuthenticated }: { isAuthenticated: boolean }) {
  const [isOpen, setIsOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (menuRef.current && !menuRef.current.contains(event.target as Node)) {
        setIsOpen(false);
      }
    }
    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === 'Escape') {
        setIsOpen(false);
      }
    }
    if (isOpen) {
      document.addEventListener('mousedown', handleClickOutside);
      document.addEventListener('keydown', handleKeyDown);
    }
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
      document.removeEventListener('keydown', handleKeyDown);
    };
  }, [isOpen]);

  const items = isAuthenticated ? LOGGED_IN_ITEMS : LOGGED_OUT_ITEMS;

  function handleSignOut() {
    setIsOpen(false);
    const api = browserToasterApiBase();
    void toasterFetch(`${api}/auth/logout`, { method: 'POST' }).finally(() => {
      window.location.href = '/login';
    });
  }

  return (
    <div ref={menuRef} className="relative">
      <button
        type="button"
        aria-label={isOpen ? 'Close menu' : 'Open menu'}
        aria-expanded={isOpen}
        aria-controls="hamburger-menu"
        onClick={() => setIsOpen((prev) => !prev)}
        className="flex h-9 w-9 items-center justify-center rounded-full border border-zinc-200 bg-white text-zinc-700 shadow-sm transition hover:bg-zinc-50 dark:border-zinc-700 dark:bg-zinc-800 dark:text-zinc-300 dark:hover:bg-zinc-700"
      >
        {isOpen ? (
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="16"
            height="16"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
            aria-hidden="true"
          >
            <line x1="18" y1="6" x2="6" y2="18" />
            <line x1="6" y1="6" x2="18" y2="18" />
          </svg>
        ) : (
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="16"
            height="16"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
            aria-hidden="true"
          >
            <line x1="3" y1="12" x2="21" y2="12" />
            <line x1="3" y1="6" x2="21" y2="6" />
            <line x1="3" y1="18" x2="21" y2="18" />
          </svg>
        )}
      </button>

      {isOpen && (
        <nav
          id="hamburger-menu"
          className="absolute right-0 top-11 z-50 min-w-44 rounded-2xl border border-zinc-200 bg-white py-2 shadow-lg dark:border-zinc-700 dark:bg-zinc-800"
        >
          {items.map(({ href, label }) => (
            <Link
              key={href}
              href={href}
              onClick={() => setIsOpen(false)}
              className="block px-4 py-2 text-sm font-medium text-zinc-700 transition hover:bg-zinc-50 hover:text-zinc-900 dark:text-zinc-300 dark:hover:bg-zinc-700 dark:hover:text-zinc-100"
            >
              {label}
            </Link>
          ))}
          {isAuthenticated && (
            <>
              <div
                role="separator"
                className="my-1 border-t border-zinc-200 dark:border-zinc-700"
              />
              <button
                type="button"
                onClick={handleSignOut}
                className="block w-full px-4 py-2 text-left text-sm font-medium text-zinc-700 transition hover:bg-zinc-50 hover:text-zinc-900 dark:text-zinc-300 dark:hover:bg-zinc-700 dark:hover:text-zinc-100"
              >
                Sign out
              </button>
            </>
          )}
        </nav>
      )}
    </div>
  );
}
