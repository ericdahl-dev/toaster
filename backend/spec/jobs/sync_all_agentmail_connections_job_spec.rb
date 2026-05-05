require "rails_helper"

RSpec.describe SyncAllAgentmailConnectionsJob, type: :job do
  describe "#perform" do
    it "schedules ingestion for each active connection" do
      account = create(:account)
      active1 = create(:agentmail_connection, account: account, active: true)
      active2 = create(:agentmail_connection, account: account, active: true)
      inactive = create(:agentmail_connection, account: account, active: false)
      allow(InboxSyncScheduler).to receive(:schedule)

      described_class.perform_now

      expect(InboxSyncScheduler).to have_received(:schedule).with(active1)
      expect(InboxSyncScheduler).to have_received(:schedule).with(active2)
      expect(InboxSyncScheduler).not_to have_received(:schedule).with(inactive)
    end

    it "uses the webhooks queue" do
      expect(described_class.queue_name).to eq("webhooks")
    end

    it "logs fan-out enqueue counts" do
      account = create(:account)
      create(:agentmail_connection, account: account, active: true)
      create(:agentmail_connection, account: account, active: true)
      allow(InboxSyncScheduler).to receive(:schedule)
      allow(Rails.logger).to receive(:info)

      described_class.perform_now

      expect(Rails.logger).to have_received(:info).with(include("agentmail_fanout_enqueued"))
      expect(Rails.logger).to have_received(:info).with(include("enqueued_count"))
    end
  end
end
