# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Accounts", type: :request do
  let(:admin) { create(:user, role: :admin) }
  let(:venue_manager) { create(:user, role: :venue_manager) }

  describe "GET /admin/accounts/new" do
    context "when unauthenticated" do
      it "redirects to login" do
        get new_admin_account_path
        expect(response).to redirect_to("/login")
      end
    end

    context "when signed in as venue_manager" do
      it "redirects to root with a flash" do
        sign_in_as(venue_manager)
        get new_admin_account_path
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end

    context "when signed in as admin" do
      it "renders the form" do
        sign_in_as(admin)
        get new_admin_account_path
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "POST /admin/accounts" do
    context "when signed in as admin with valid params" do
      it "creates an account and initial user, redirects" do
        sign_in_as(admin)
        expect {
          post admin_accounts_path, params: {
            account: { name: "New Venue Co" },
            user: { name: "Owner Name", email: "owner@example.com", password: "password123" }
          }
        }.to change(Account, :count).by(1).and change(User, :count).by(1)

        new_account = Account.order(:created_at).last
        new_user = new_account.users.first
        expect(new_user.email).to eq("owner@example.com")
        expect(new_user.role).to eq("venue_manager")
        expect(response).to redirect_to(new_admin_account_path)
        expect(flash[:notice]).to be_present
      end

      it "does not fire admin_account_created to PostHog in the test environment" do
        sign_in_as(admin)
        expect(PostHog).not_to receive(:capture)
        post admin_accounts_path, params: {
          account: { name: "New Venue Co" },
          user: { name: "Owner Name", email: "owner@example.com", password: "password123" }
        }
      end
    end

    context "when signed in as admin with invalid params" do
      it "re-renders the form" do
        sign_in_as(admin)
        post admin_accounts_path, params: { account: { name: "" }, user: { name: "", email: "", password: "" } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
