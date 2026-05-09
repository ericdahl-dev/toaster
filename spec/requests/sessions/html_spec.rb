# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sessions (HTML)", type: :request do
  let(:account) { create(:account) }
  let!(:user) { create(:user, account: account) }

  describe "GET /login" do
    it "renders the login form" do
      get "/login"

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to match(%r{text/html})
      expect(response.body).to include("login")
    end

    it "redirects signed-in users to the root page" do
      sign_in user

      get "/login"

      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to("/")
    end
  end

  describe "POST /login" do
    context "with valid credentials" do
      it "sets session and redirects" do
        post "/login", params: { user: { email: user.email, password: "password123" } }

        expect(response).to have_http_status(:redirect)
        follow_redirect!
        expect(response).to have_http_status(:ok)
      end

      it "authenticates a user with a migrated bcrypt digest" do
        user.update_columns(
          encrypted_password: BCrypt::Password.create("password123"),
          updated_at: Time.current
        )

        post "/login", params: { user: { email: user.email, password: "password123" } }

        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to("/")
      end
    end

    context "with invalid credentials" do
      it "re-renders the form with an error" do
        post "/login", params: { user: { email: user.email, password: "wrong" } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to match(/invalid email or password/i)
      end
    end
  end

  describe "DELETE /logout" do
    it "clears session and redirects to login" do
      post "/login", params: { user: { email: user.email, password: "password123" } }

      delete "/logout"

      expect(response).to have_http_status(:redirect)
      expect(response.location).to include("/login")
    end
  end
end
