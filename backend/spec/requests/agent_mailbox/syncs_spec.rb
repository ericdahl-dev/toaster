require "rails_helper"

RSpec.describe "Agent mailbox sync", type: :request do
  describe "POST /accounts/:account_id/agent_mailbox/sync" do
    it "enqueues a sync job for each active connection" do
      account = create(:account)
      conn1 = create(:agentmail_connection, account: account)
      conn2 = create(:agentmail_connection, account: account)

      expect {
        post "/accounts/#{account.id}/agent_mailbox/sync"
      }.to have_enqueued_job(SyncAgentMailboxJob).with(conn1.id)
        .and have_enqueued_job(SyncAgentMailboxJob).with(conn2.id)

      expect(response).to have_http_status(:accepted)
      expect(response.parsed_body).to include(
        "status" => "enqueued",
        "account_id" => account.id,
        "connection_count" => 2
      )
    end

    it "returns accepted with 0 connection_count when no active connections exist" do
      account = create(:account)

      post "/accounts/#{account.id}/agent_mailbox/sync"

      expect(response).to have_http_status(:accepted)
      expect(response.parsed_body["connection_count"]).to eq(0)
    end

    it "returns 404 for an unknown account" do
      post "/accounts/999999/agent_mailbox/sync"

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body).to include("error" => "Account not found")
    end
  end
end
