# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Onboarding", type: :request do
  let(:account) { create(:account, onboarded_at: nil) }
  let!(:user) { create(:user, account: account) }

  def sign_in_as(u)
    post "/login", params: {user: {email: u.email, password: "password123"}}
  end

  describe "sign-in redirect" do
    context "new user (no venues, no connections)" do
      it "redirects to onboarding after sign-in" do
        sign_in_as(user)
        expect(response).to redirect_to(onboarding_path)
      end
    end

    context "account already has venue and connection" do
      before do
        create(:venue, account: account)
        create(:imap_connection, account: account)
      end

      it "redirects to booking requests after sign-in" do
        sign_in_as(user)
        expect(response).to redirect_to(booking_requests_path)
      end
    end

    context "account has onboarded_at stamped" do
      before { account.update!(onboarded_at: 1.day.ago) }

      it "redirects to booking requests after sign-in" do
        sign_in_as(user)
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
    end
  end

  describe "GET /onboarding/venue" do
    before { sign_in_as(user) }

    it "renders the venue step" do
      get "/onboarding/venue"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /onboarding/mail_connection" do
    before { sign_in_as(user) }

    it "renders the mail connection step" do
      get "/onboarding/mail_connection"
      expect(response).to have_http_status(:ok)
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
end
