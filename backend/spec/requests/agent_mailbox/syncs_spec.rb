# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Agent mailbox sync", type: :request do
  describe "POST /accounts/:account_id/agent_mailbox/sync" do
    let(:account) { create(:account) }
    let(:user) { create(:user, account: account) }

    before { sign_in_as(user) }

    it "schedules ingestion for each active connection" do
      conn1 = create(:agentmail_connection, account: account)
      conn2 = create(:agentmail_connection, account: account)

      allow(InboxSyncScheduler).to receive(:schedule)

      post "/accounts/#{account.id}/agent_mailbox/sync"

      expect(InboxSyncScheduler).to have_received(:schedule).with(conn1)
      expect(InboxSyncScheduler).to have_received(:schedule).with(conn2)
      expect(response).to have_http_status(:accepted)
      expect(response.parsed_body).to include(
        "status" => "enqueued",
        "account_id" => account.id,
        "connection_count" => 2
      )
    end

    it "returns accepted with 0 connection_count when no active connections exist" do
      post "/accounts/#{account.id}/agent_mailbox/sync"

      expect(response).to have_http_status(:accepted)
      expect(response.parsed_body["connection_count"]).to eq(0)
    end

    it "returns 403 for an account id that is not the signed-in user's account" do
      post "/accounts/999999/agent_mailbox/sync"

      expect(response).to have_http_status(:forbidden)
    end
  end
end
