# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Onboarding", type: :request do
  let(:account) { create(:account, onboarded_at: nil) }
  let!(:user) { create(:user, account: account) }

  def post_login(u)
    get "/login"
    post "/login", params: { user: { email: u.email, password: "password123" } }
  end

  describe "sign-in redirect" do
    context "new user (no venues, no connections)" do
      it "redirects to onboarding after sign-in" do
        post_login(user)
        expect(response).to redirect_to(onboarding_path)
      end
    end

    context "account already has venue and connection" do
      before do
        create(:venue, account: account)
        create(:imap_connection, account: account)
      end

      it "redirects to booking requests after sign-in" do
        post_login(user)
        expect(response).to redirect_to(booking_requests_path)
      end
    end

    context "account has onboarded_at stamped" do
      before { account.update!(onboarded_at: 1.day.ago) }

      it "redirects to booking requests after sign-in" do
        post_login(user)
        expect(response).to redirect_to(booking_requests_path)
      end
    end
  end

  describe "GET /onboarding" do
    context "when not signed in" do
      it "redirects to login" do
        get "/onboarding"
        expect(response).to redirect_to(login_path)
      end
    end

    context "when signed in and not onboarded" do
      before { sign_in_as(user) }

      it "renders the welcome step" do
        get "/onboarding"
        expect(response).to have_http_status(:ok)
      end

      it "renders login-box chrome" do
        get "/onboarding"
        expect(response.body).to include("login-box")
      end

      it "renders the Toaster logo" do
        get "/onboarding"
        expect(response.body).to include("login-logo")
      end

      it "renders skip link with auth-link class" do
        get "/onboarding"
        expect(response.body).to match(/class="[^"]*auth-link[^"]*"/)
      end
    end
  end

  describe "GET /onboarding/venue" do
    before { sign_in_as(user) }

    it "renders the venue step" do
      get "/onboarding/venue"
      expect(response).to have_http_status(:ok)
    end

    it "renders form-input styled fields" do
      get "/onboarding/venue"
      expect(response.body).to include("form-input")
    end

    it "renders btn-amber submit" do
      get "/onboarding/venue"
      expect(response.body).to include("btn-amber")
    end

    it "renders login-box chrome" do
      get "/onboarding/venue"
      expect(response.body).to include("login-box")
    end

    it "renders skip link with auth-link class" do
      get "/onboarding/venue"
      expect(response.body).to match(/class="[^"]*auth-link[^"]*"/)
    end

    it "submits venue and redirects to mail connection step" do
      sign_in user
      post "/venues", params: { venue: { name: "The Grand Hall" }, onboarding: true }

      expect(response).to redirect_to(onboarding_mail_connection_path)
      expect(user.account.venues.find_by(name: "The Grand Hall")).not_to be_nil
    end

    it "re-renders onboarding venue form on validation failure" do
      sign_in user
      post "/venues", params: { venue: { name: "" }, onboarding: true }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("login-box")
    end
  end

  describe "GET /onboarding/mail_connection" do
    before { sign_in_as(user) }

    it "renders the mail connection step" do
      get "/onboarding/mail_connection"
      expect(response).to have_http_status(:ok)
    end

    it "renders form-input styled fields" do
      get "/onboarding/mail_connection"
      expect(response.body).to include("form-input")
    end

    it "renders btn-amber submit" do
      get "/onboarding/mail_connection"
      expect(response.body).to include("btn-amber")
    end

    it "renders login-box chrome" do
      get "/onboarding/mail_connection"
      expect(response.body).to include("login-box")
    end

    it "renders skip link with auth-link class" do
      get "/onboarding/mail_connection"
      expect(response.body).to match(/class="[^"]*auth-link[^"]*"/)
    end

    it "submits IMAP credentials and redirects to onboarding complete" do
      sign_in user
      post "/mail_connections", params: {
        mail_connection: {
          type: "imap",
          host: "imap.gmail.com",
          port: 993,
          username: "test@venue.com",
          password: "secret"
        },
        onboarding: true
      }

      expect(response).to redirect_to(onboarding_complete_path)
      expect(user.account.imap_connections.find_by(username: "test@venue.com")).not_to be_nil
    end

    it "re-renders onboarding mail connection form on validation failure" do
      sign_in user
      post "/mail_connections", params: {
        mail_connection: { type: "imap", host: "", port: 993, username: "", password: "" },
        onboarding: true
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("login-box")
    end
  end

  describe "POST /onboarding/skip" do
    before { sign_in_as(user) }

    it "stamps onboarded_at and redirects to booking requests" do
      post "/onboarding/skip"
      expect(account.reload.onboarded_at).not_to be_nil
      expect(response).to redirect_to(booking_requests_path)
    end
  end

  describe "GET /onboarding/complete" do
    before { sign_in_as(user) }

    it "stamps onboarded_at and redirects to booking requests" do
      get "/onboarding/complete"
      expect(account.reload.onboarded_at).not_to be_nil
      expect(response).to redirect_to(booking_requests_path)
    end
  end

  describe "password reset redirect (invited user)" do
    let(:raw_token) do
      raw, hashed = Devise.token_generator.generate(User, :reset_password_token)
      user.update_columns(reset_password_token: hashed, reset_password_sent_at: Time.current)
      raw
    end

    context "new user resets password for the first time" do
      it "redirects to onboarding after password reset" do
        put "/password",
          params: {
            user: {
              reset_password_token: raw_token,
              password: "newpassword123",
              password_confirmation: "newpassword123"
            }
          }

        expect(response).to redirect_to(onboarding_path)
      end
    end
  end
end
