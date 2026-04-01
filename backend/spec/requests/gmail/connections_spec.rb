require "rails_helper"

RSpec.describe "Gmail Connections", type: :request do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let!(:connection) { create(:gmail_connection, account: account, user: user) }

  describe "GET /accounts/:account_id/gmail/connections" do
    it "returns all connections for the account" do
      get "/accounts/#{account.id}/gmail/connections"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["connections"].length).to eq(1)
      expect(body["connections"].first["email"]).to eq(connection.email)
    end

    it "returns connection health fields" do
      get "/accounts/#{account.id}/gmail/connections"

      conn = response.parsed_body["connections"].first
      expect(conn).to have_key("watch_active")
      expect(conn).to have_key("watch_expires_soon")
      expect(conn).to have_key("healthy")
    end

    it "returns 404 for an unknown account" do
      get "/accounts/99999/gmail/connections"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /accounts/:account_id/gmail/connections/:id" do
    it "returns the connection with health metadata" do
      get "/accounts/#{account.id}/gmail/connections/#{connection.id}"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["connection"]["id"]).to eq(connection.id)
      expect(body["connection"]["email"]).to eq(connection.email)
      expect(body["connection"]).to have_key("watch_active")
      expect(body["connection"]).to have_key("healthy")
    end

    it "returns 404 for an unknown connection" do
      get "/accounts/#{account.id}/gmail/connections/99999"
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 when connection belongs to a different account" do
      other_account = create(:account)
      get "/accounts/#{other_account.id}/gmail/connections/#{connection.id}"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /accounts/:account_id/gmail/connections/:id/reconnect" do
    it "returns an authorization URL for re-authentication" do
      oauth_service = instance_double(GmailOauthService, authorization_url: "https://accounts.google.com/o/oauth2/v2/auth?reconnect=true")
      allow(GmailOauthService).to receive(:new).and_return(oauth_service)

      post "/accounts/#{account.id}/gmail/connections/#{connection.id}/reconnect"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body).to have_key("auth_url")
      expect(body["auth_url"]).to start_with("https://accounts.google.com")
    end

    it "returns 404 for an unknown connection" do
      post "/accounts/#{account.id}/gmail/connections/99999/reconnect"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /accounts/:account_id/gmail/connections/:id/resync" do
    context "when watch renewal succeeds" do
      it "renews the watch and returns the updated connection" do
        watch_service = instance_double(GmailWatchService)
        allow(GmailWatchService).to receive(:new).with(connection).and_return(watch_service)
        allow(watch_service).to receive(:renew) do
          connection.update!(watch_expiration: 7.days.from_now, watch_history_id: "99999")
        end

        post "/accounts/#{account.id}/gmail/connections/#{connection.id}/resync"

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["connection"]["watch_active"]).to be true
      end
    end

    context "when watch renewal fails" do
      it "returns unprocessable_entity with an error message" do
        watch_service = instance_double(GmailWatchService)
        allow(GmailWatchService).to receive(:new).with(connection).and_return(watch_service)
        allow(watch_service).to receive(:renew).and_raise(GmailWatchService::Error, "Pub/Sub topic not found")

        post "/accounts/#{account.id}/gmail/connections/#{connection.id}/resync"

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["error"]).to eq("Pub/Sub topic not found")
      end
    end

    it "returns 404 for an unknown connection" do
      post "/accounts/#{account.id}/gmail/connections/99999/resync"
      expect(response).to have_http_status(:not_found)
    end
  end
end
