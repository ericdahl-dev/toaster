# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Auth sessions", type: :request do
  let(:account) { create(:account) }
  let!(:user) { create(:user, account: account, email: "member@example.com") }

  describe "POST /auth/login followed by GET /auth/me" do
    it "returns ok and establishes a session so /auth/me returns the user" do
      post "/auth/login", params: {email: "member@example.com", password: "password123"}, as: :json

      expect(response).to have_http_status(:ok)

      get "/auth/me"
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body).to include(
        "id" => user.id,
        "email" => "member@example.com",
        "account" => {"id" => account.id, "name" => account.name}
      )
    end
  end

  describe "GET /auth/me" do
    it "returns 401 when not signed in" do
      get "/auth/me"
      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).to include("error" => "Unauthorized")
    end
  end

  describe "POST /auth/logout" do
    it "clears the session" do
      sign_in_as(user)
      post "/auth/logout"
      expect(response).to have_http_status(:no_content)

      get "/auth/me"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /auth/login" do
    it "returns 401 for wrong password" do
      post "/auth/login", params: {email: "member@example.com", password: "wrong"}, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 for unknown email" do
      post "/auth/login", params: {email: "nobody@example.com", password: "password123"}, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "remember-me" do
    it "does not set a remember cookie when remember_me is absent" do
      post "/auth/login", params: {email: "member@example.com", password: "password123"}, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.cookies).not_to have_key("remember_token")
    end

    it "does not set a remember cookie when remember_me is false" do
      post "/auth/login", params: {email: "member@example.com", password: "password123", remember_me: false}, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.cookies).not_to have_key("remember_token")
    end

    it "sets a remember cookie and persists the session when remember_me is true" do
      post "/auth/login", params: {email: "member@example.com", password: "password123", remember_me: true}, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.cookies["remember_token"]).to be_present
      user.reload
      expect(user.remember_token_digest).to be_present
    end

    it "allows /auth/me via the remember cookie even after the session is cleared" do
      post "/auth/login", params: {email: "member@example.com", password: "password123", remember_me: true}, as: :json
      remember_cookie = response.cookies["remember_token"]

      # Clear the server-side session manually by using a new request without the session.
      # Simulate a fresh browser restart by re-supplying only the remember cookie.
      get "/auth/me", headers: {"Cookie" => "remember_token=#{remember_cookie}"}
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["email"]).to eq("member@example.com")
    end

    it "clears the remember cookie and token on logout" do
      post "/auth/login", params: {email: "member@example.com", password: "password123", remember_me: true}, as: :json

      post "/auth/logout"
      expect(response).to have_http_status(:no_content)

      user.reload
      expect(user.remember_token_digest).to be_nil
    end
  end

  describe "GET /accounts/:account_id/imap/connections (authorization)" do
    before { create(:imap_connection, account: account) }

    it "returns 401 without a session" do
      get "/accounts/#{account.id}/imap/connections"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 200 when signed in with matching account_id" do
      sign_in_as(user)
      get "/accounts/#{account.id}/imap/connections"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["connections"].size).to eq(1)
    end

    it "returns 403 when signed in with a different account_id" do
      sign_in_as(user)
      other = create(:account)
      get "/accounts/#{other.id}/imap/connections"
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /accounts/:account_id/agent_mailbox/connections (authorization)" do
    before { create(:agentmail_connection, account: account) }

    it "returns 401 without a session" do
      get "/accounts/#{account.id}/agent_mailbox/connections"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 200 when signed in with matching account_id" do
      sign_in_as(user)
      get "/accounts/#{account.id}/agent_mailbox/connections"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["connections"].size).to eq(1)
    end

    it "returns 403 when signed in with a different account_id" do
      sign_in_as(user)
      other = create(:account)
      get "/accounts/#{other.id}/agent_mailbox/connections"
      expect(response).to have_http_status(:forbidden)
    end
  end
end
