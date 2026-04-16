require "rails_helper"

RSpec.describe SyncAllImapConnectionsJob, type: :job do
  describe "#perform" do
    it "enqueues SyncImapJob for each active connection" do
      account = create(:account)
      active1 = create(:imap_connection, account: account, active: true)
      active2 = create(:imap_connection, account: account, host: "imap.other.com", active: true)
      inactive = create(:imap_connection, account: account, host: "imap.inactive.com", active: false)

      allow(SyncImapJob).to receive(:perform_later)

      described_class.perform_now

      expect(SyncImapJob).to have_received(:perform_later).with(active1.id)
      expect(SyncImapJob).to have_received(:perform_later).with(active2.id)
      expect(SyncImapJob).not_to have_received(:perform_later).with(inactive.id)
    end

    it "uses the webhooks queue" do
      expect(described_class.queue_name).to eq("webhooks")
    end

    it "does nothing when there are no active connections" do
      ImapConnection.update_all(active: false)
      allow(SyncImapJob).to receive(:perform_later)

      described_class.perform_now

      expect(SyncImapJob).not_to have_received(:perform_later)
    end
  end
end
