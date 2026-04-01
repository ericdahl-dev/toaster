require "rails_helper"

RSpec.describe "Agent mailbox sync", type: :request do
  describe "POST /accounts/:account_id/agent_mailbox/sync" do
    it "enqueues a sync job for the account" do
      account = create(:account)

      expect {
        post "/accounts/#{account.id}/agent_mailbox/sync"
      }.to have_enqueued_job(SyncAgentMailboxJob).with(account.id)

      expect(response).to have_http_status(:accepted)
      expect(response.parsed_body).to include(
        "status" => "enqueued",
        "account_id" => account.id
      )
    end

    it "returns 404 for an unknown account" do
      post "/accounts/999999/agent_mailbox/sync"

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body).to include("error" => "Account not found")
    end
  end
end
