require "rails_helper"

RSpec.describe SyncAgentMailboxJob, type: :job do
  describe "#perform" do
    it "delegates to InboxIngestion::Sync with an AgentMailbox adapter" do
      connection = create(:agentmail_connection)

      expect(InboxIngestion::Sync).to receive(:call) do |kwargs|
        expect(kwargs[:adapter]).to be_a(InboxIngestion::AgentMailboxAdapter)
        expect(kwargs[:adapter].account).to eq(connection.account)
        InboxIngestion::Sync::Result.new(created_count: 0, deduped_count: 0, messages: [])
      end

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
      connection = create(:agentmail_connection, last_synced_at: Time.current)
      result = InboxIngestion::Sync::Result.new(created_count: 3, deduped_count: 2, messages: [])
      allow(InboxIngestion::Sync).to receive(:call).and_return(result)
      allow(Rails.logger).to receive(:info)

      described_class.perform_now(connection.id)

      expect(Rails.logger).to have_received(:info).with(include("agentmail_sync_result"))
      expect(Rails.logger).to have_received(:info).with(include("created_count"))
      expect(Rails.logger).to have_received(:info).with(include("deduped_count"))
      expect(Rails.logger).to have_received(:info).with(include("last_synced_at"))
    end
  end
end
