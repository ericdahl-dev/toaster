# frozen_string_literal: true

require "rails_helper"

RSpec.describe ImapBackfillJob, type: :job do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:connection) { create(:imap_connection, account: account, last_synced_uid: 100) }

  before do
    allow(BookingRequests::Reconcile).to receive(:call).and_return(nil)
    allow(Imap::Fetcher).to receive(:new).and_return(fetcher)
    allow(fetcher).to receive(:fetch_messages).and_return([])
    allow(fetcher).to receive(:mailbox_peak_uid).and_return(100)
  end

  let(:fetcher) { instance_double(Imap::Fetcher) }

  it "syncs with a SINCE override fetcher and records backfill metadata" do
    since_override = instance_double(InboxIngestion::SinceOverrideFetcher)
    allow(InboxIngestion::SinceOverrideFetcher).to receive(:new).and_return(since_override)
    adapter = instance_double(InboxIngestion::ImapAdapter)
    allow(InboxIngestion::ImapAdapter).to receive(:new).and_return(adapter)
    allow(InboxIngestion::Sync).to receive(:call)

    described_class.perform_now(connection.id, 30)

    expect(InboxIngestion::SinceOverrideFetcher).to have_received(:new).with(fetcher, since: 30.days.ago.to_date)
    expect(InboxIngestion::Sync).to have_received(:call).with(adapter: adapter)
    expect(connection.reload.last_backfill_days).to eq(30)
    expect(connection.last_backfill_at).to be_present
  end

  it "rejects invalid day windows" do
    expect {
      described_class.perform_now(connection.id, 14)
    }.to raise_error(ArgumentError, /invalid backfill days/)
  end
end
