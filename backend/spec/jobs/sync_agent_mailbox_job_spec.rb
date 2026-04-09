require "rails_helper"

RSpec.describe SyncAgentMailboxJob, type: :job do
  describe "#perform" do
    it "delegates to AgentMailbox::Sync for the connection" do
      connection = create(:agentmail_connection)

      expect(AgentMailbox::Sync).to receive(:call).with(connection: connection)

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
  end
end
