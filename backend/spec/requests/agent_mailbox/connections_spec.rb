# frozen_string_literal: true

require "rails_helper"

RSpec.describe "AgentMailbox::Connections", type: :request do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let!(:connection) { create(:agentmail_connection, account: account) }

  context "when signed in" do
    before { sign_in_as(user) }

    describe "GET /accounts/:account_id/agent_mailbox/connections" do
      it "returns all AgentMail connections for the account" do
        get "/accounts/#{account.id}/agent_mailbox/connections"

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["connections"].length).to eq(1)
        expect(body["connections"].first["inbox_id"]).to eq(connection.inbox_id)
      end

      it "does not expose the api_key" do
        get "/accounts/#{account.id}/agent_mailbox/connections"

        conn = response.parsed_body["connections"].first
        expect(conn).not_to have_key("api_key")
      end

      it "returns 403 for an account id that is not the signed-in user's account" do
        get "/accounts/99999/agent_mailbox/connections"
        expect(response).to have_http_status(:forbidden)
      end
    end

    describe "POST /accounts/:account_id/agent_mailbox/connections" do
      let(:valid_params) do
        {agentmail_connection: {inbox_id: "new@agentmail.to", api_key: "key-123"}}
      end

      it "creates a connection and schedules ingestion" do
        allow(InboxSyncScheduler).to receive(:schedule)

        post "/accounts/#{account.id}/agent_mailbox/connections", params: valid_params, as: :json

        expect(response).to have_http_status(:created)
        body = response.parsed_body
        expect(body["connection"]["inbox_id"]).to eq("new@agentmail.to")
        expect(body["connection"]).not_to have_key("api_key")
        created = AgentmailConnection.find(body["connection"]["id"])
        expect(InboxSyncScheduler).to have_received(:schedule).with(created)
      end

      it "returns errors for invalid params" do
        post "/accounts/#{account.id}/agent_mailbox/connections",
          params: {agentmail_connection: {inbox_id: "", api_key: ""}},
          as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["errors"]).to be_present
      end

      it "returns 403 for an account id that is not the signed-in user's account" do
        post "/accounts/99999/agent_mailbox/connections", params: valid_params, as: :json
        expect(response).to have_http_status(:forbidden)
      end
    end

    describe "GET /accounts/:account_id/agent_mailbox/connections/:id" do
      it "returns the connection" do
        get "/accounts/#{account.id}/agent_mailbox/connections/#{connection.id}"

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["connection"]["id"]).to eq(connection.id)
        expect(body["connection"]["inbox_id"]).to eq(connection.inbox_id)
      end

      it "returns 404 for an unknown connection" do
        get "/accounts/#{account.id}/agent_mailbox/connections/99999"
        expect(response).to have_http_status(:not_found)
      end

      it "returns 403 when the connection belongs to a different account" do
        other_account = create(:account)
        get "/accounts/#{other_account.id}/agent_mailbox/connections/#{connection.id}"
        expect(response).to have_http_status(:forbidden)
      end
    end

    describe "PATCH /accounts/:account_id/agent_mailbox/connections/:id" do
      it "updates the connection" do
        patch "/accounts/#{account.id}/agent_mailbox/connections/#{connection.id}",
          params: {agentmail_connection: {active: false}},
          as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["connection"]["active"]).to eq(false)
      end

      it "returns 404 for an unknown connection" do
        patch "/accounts/#{account.id}/agent_mailbox/connections/99999",
          params: {agentmail_connection: {active: false}},
          as: :json
        expect(response).to have_http_status(:not_found)
      end
    end

    describe "DELETE /accounts/:account_id/agent_mailbox/connections/:id" do
      it "destroys the connection" do
        delete "/accounts/#{account.id}/agent_mailbox/connections/#{connection.id}"
        expect(response).to have_http_status(:no_content)
        expect(AgentmailConnection.find_by(id: connection.id)).to be_nil
      end

      it "returns 404 for an unknown connection" do
        delete "/accounts/#{account.id}/agent_mailbox/connections/99999"
        expect(response).to have_http_status(:not_found)
      end
    end

    describe "POST /accounts/:account_id/agent_mailbox/connections/:id/sync" do
      it "schedules ingestion and returns accepted" do
        allow(InboxSyncScheduler).to receive(:schedule)

        post "/accounts/#{account.id}/agent_mailbox/connections/#{connection.id}/sync"

        expect(response).to have_http_status(:accepted)
        body = response.parsed_body
        expect(body["status"]).to eq("enqueued")
        expect(body["agentmail_connection_id"]).to eq(connection.id)
        expect(InboxSyncScheduler).to have_received(:schedule).with(connection)
      end

      it "returns 404 for an unknown connection" do
        post "/accounts/#{account.id}/agent_mailbox/connections/99999/sync"
        expect(response).to have_http_status(:not_found)
      end

      it "returns 403 for an account id that is not the signed-in user's account" do
        post "/accounts/99999/agent_mailbox/connections/#{connection.id}/sync"
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
