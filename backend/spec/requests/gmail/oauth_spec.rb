require "rails_helper"

RSpec.describe "Gmail OAuth", type: :request do
  let(:account) { create(:account) }
  let!(:user) { create(:user, account: account) }

  describe "GET /gmail/oauth/start" do
    context "with a valid account_id" do
      it "returns an authorization URL" do
        oauth_service = instance_double(GmailOauthService, authorization_url: "https://accounts.google.com/o/oauth2/v2/auth?client_id=x")
        allow(GmailOauthService).to receive(:new).and_return(oauth_service)

        get "/gmail/oauth/start", params: {account_id: account.id}

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body).to have_key("auth_url")
        expect(body["auth_url"]).to start_with("https://accounts.google.com")
      end
    end

    context "with an invalid account_id" do
      it "returns 404" do
        get "/gmail/oauth/start", params: {account_id: 99999}
        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body["error"]).to eq("Account not found")
      end
    end

    context "without account_id" do
      it "returns bad_request" do
        get "/gmail/oauth/start"
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe "GET /gmail/oauth/callback" do
    let(:code) { "auth_code_from_google" }
    let(:state) { Base64.strict_encode64({account_id: account.id}.to_json) }
    let(:token_data) do
      {
        "access_token" => "ya29.access_token",
        "refresh_token" => "1//refresh_token",
        "expires_in" => 3600,
        "token_type" => "Bearer"
      }
    end

    context "with valid code and state" do
      it "creates a Gmail connection and returns it" do
        oauth_service = instance_double(GmailOauthService)
        allow(GmailOauthService).to receive(:new).and_return(oauth_service)
        allow(oauth_service).to receive(:exchange_code).with(code).and_return(token_data)
        allow(oauth_service).to receive(:fetch_user_email).with("ya29.access_token").and_return("user@gmail.com")

        expect {
          get "/gmail/oauth/callback", params: {code: code, state: state}
        }.to change(GmailConnection, :count).by(1)

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["connection"]["email"]).to eq("user@gmail.com")
        expect(body["connection"]["active"]).to be true
        expect(body["connection"]).to have_key("watch_active")
        expect(body["connection"]).to have_key("healthy")
      end

      it "updates an existing connection without creating a duplicate" do
        existing = create(:gmail_connection, account: account, user: user, email: "user@gmail.com")
        oauth_service = instance_double(GmailOauthService)
        allow(GmailOauthService).to receive(:new).and_return(oauth_service)
        allow(oauth_service).to receive(:exchange_code).with(code).and_return(token_data)
        allow(oauth_service).to receive(:fetch_user_email).with("ya29.access_token").and_return("user@gmail.com")

        expect {
          get "/gmail/oauth/callback", params: {code: code, state: state}
        }.not_to change(GmailConnection, :count)

        expect(response).to have_http_status(:ok)
        expect(existing.reload.access_token).to eq("ya29.access_token")
      end
    end

    context "when code exchange fails" do
      it "returns unprocessable_entity" do
        oauth_service = instance_double(GmailOauthService)
        allow(GmailOauthService).to receive(:new).and_return(oauth_service)
        allow(oauth_service).to receive(:exchange_code).and_raise(GmailOauthService::Error, "invalid_grant")

        get "/gmail/oauth/callback", params: {code: "bad_code", state: state}

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["error"]).to eq("invalid_grant")
      end
    end

    context "with invalid state encoding" do
      it "returns bad_request" do
        get "/gmail/oauth/callback", params: {code: code, state: "not-valid-base64!!!"}
        expect(response).to have_http_status(:bad_request)
      end
    end

    context "with state pointing to a non-existent account" do
      it "returns not_found" do
        bad_state = Base64.strict_encode64({account_id: 99999}.to_json)
        oauth_service = instance_double(GmailOauthService)
        allow(GmailOauthService).to receive(:new).and_return(oauth_service)
        allow(oauth_service).to receive(:exchange_code).and_return(token_data)
        allow(oauth_service).to receive(:fetch_user_email).and_return("user@gmail.com")

        get "/gmail/oauth/callback", params: {code: code, state: bad_state}

        expect(response).to have_http_status(:not_found)
      end
    end

    context "without code parameter" do
      it "returns bad_request" do
        get "/gmail/oauth/callback", params: {state: state}
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
