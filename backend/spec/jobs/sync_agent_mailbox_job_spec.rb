require "rails_helper"

RSpec.describe SyncAgentMailboxJob, type: :job do
  describe "#perform" do
    it "delegates to AgentMailbox::Sync for the account" do
      account = create(:account)

      expect(AgentMailbox::Sync).to receive(:call).with(account: account)

      described_class.perform_now(account.id)
    end

    it "uses the webhooks queue" do
      expect(described_class.queue_name).to eq("webhooks")
    end
  end
end
