require "rails_helper"

RSpec.describe SyncImapJob, type: :job do
  describe "#perform" do
    it "delegates to Imap::Sync for the connection" do
      connection = create(:imap_connection)

      expect(Imap::Sync).to receive(:call).with(imap_connection: connection)

      described_class.perform_now(connection.id)
    end

    it "uses the webhooks queue" do
      expect(described_class.queue_name).to eq("webhooks")
    end

    it "discards the job when the connection no longer exists" do
      expect {
        described_class.perform_now(0)
      }.not_to raise_error
    end

    it "logs a sync result summary" do
      connection = create(:imap_connection, last_synced_uid: 3)
      result = Imap::Sync::Result.new(created_count: 2, deduped_count: 1, messages: [])
      allow(Imap::Sync).to receive(:call).and_return(result)
      allow(Rails.logger).to receive(:info)

      described_class.perform_now(connection.id)

      expect(Rails.logger).to have_received(:info).with(include("imap_sync_result"))
      expect(Rails.logger).to have_received(:info).with(include("created_count"))
      expect(Rails.logger).to have_received(:info).with(include("deduped_count"))
      expect(Rails.logger).to have_received(:info).with(include("last_synced_uid"))
    end
  end
end
