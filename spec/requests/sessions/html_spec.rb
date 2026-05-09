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
  end

  describe "POST /login" do
    context "with valid credentials" do
      it "sets session and redirects" do
        post "/login", params: {user: {email: user.email, password: "password123"}}

        expect(response).to have_http_status(:redirect)
        follow_redirect!
        expect(response).to have_http_status(:ok)
      end
    end

    context "with invalid credentials" do
      it "re-renders the form with an error" do
        post "/login", params: {user: {email: user.email, password: "wrong"}}

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to match(/invalid email or password/i)
      end
    end
  end

  describe "POST /login — waitlist conversion" do
    context "when the user has an invited WaitlistEntry and this is their first sign in" do
      let!(:entry) { create(:waitlist_entry, email: user.email, status: :invited, invited_at: 1.day.ago) }

      it "marks the WaitlistEntry as converted" do
        post "/login", params: {user: {email: user.email, password: "password123"}}

        expect(entry.reload).to be_converted
      end
    end

    context "when the user has no WaitlistEntry" do
      it "signs in normally without error" do
        post "/login", params: {user: {email: user.email, password: "password123"}}

        expect(response).to have_http_status(:redirect)
      end
    end
  end
end

