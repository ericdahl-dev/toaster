require "rails_helper"

RSpec.describe SyncAllAgentmailConnectionsJob, type: :job do
  describe "#perform" do
    it "enqueues SyncAgentMailboxJob for each active connection" do
      account = create(:account)
      active1 = create(:agentmail_connection, account: account, active: true)
      active2 = create(:agentmail_connection, account: account, active: true)
      inactive = create(:agentmail_connection, account: account, active: false)
      allow(SyncAgentMailboxJob).to receive(:perform_later)

      described_class.perform_now

      expect(SyncAgentMailboxJob).to have_received(:perform_later).with(active1.id)
      expect(SyncAgentMailboxJob).to have_received(:perform_later).with(active2.id)
      expect(SyncAgentMailboxJob).not_to have_received(:perform_later).with(inactive.id)
    end

    it "uses the webhooks queue" do
      expect(described_class.queue_name).to eq("webhooks")
    end

    it "logs fan-out enqueue counts" do
      account = create(:account)
      create(:agentmail_connection, account: account, active: true)
      create(:agentmail_connection, account: account, active: true)
      allow(SyncAgentMailboxJob).to receive(:perform_later)
      allow(Rails.logger).to receive(:info)

      described_class.perform_now

      expect(Rails.logger).to have_received(:info).with(include("agentmail_fanout_enqueued"))
      expect(Rails.logger).to have_received(:info).with(include("enqueued_count"))
    end
  end
end
