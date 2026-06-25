# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Users", type: :request do
  let(:admin) { create(:user, role: :admin) }
  let(:venue_manager) { create(:user, role: :venue_manager) }
  let(:target_account) { create(:account) }

  describe "GET /admin/users/new" do
    context "when unauthenticated" do
      it "redirects to login" do
        get new_admin_user_path
        expect(response).to redirect_to("/login")
      end
    end

    context "when signed in as venue_manager" do
      it "redirects to root with a flash" do
        sign_in_as(venue_manager)
        get new_admin_user_path
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end

    context "when signed in as admin" do
      it "renders the form" do
        sign_in_as(admin)
        get new_admin_user_path
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "POST /admin/users" do
    context "when signed in as admin with valid params" do
      it "creates a user on the target account" do
        sign_in_as(admin)
        expect {
          post admin_users_path, params: {
            user: {
              account_id: target_account.id,
              name: "New User",
              email: "newuser@example.com",
              password: "password123"
            }
          }
        }.to change(User, :count).by(1)

        new_user = User.order(:created_at).last
        expect(new_user.account).to eq(target_account)
        expect(new_user.role).to eq("venue_manager")
        expect(response).to redirect_to(new_admin_user_path)
        expect(flash[:notice]).to be_present
      end
    end

    context "when signed in as admin with invalid params" do
      it "re-renders the form" do
        sign_in_as(admin)
        post admin_users_path, params: { user: { account_id: target_account.id, name: "", email: "", password: "" } }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
