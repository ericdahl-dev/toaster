# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Users", type: :request do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, name: "Owner", email: "owner@example.com") }

  context "when signed in" do
    before { sign_in_as(user) }

    describe "GET /accounts/:account_id/users" do
      it "returns all users for the account" do
        get "/accounts/#{account.id}/users"

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["users"].length).to eq(1)
        expect(body["users"].first["name"]).to eq("Owner")
      end

      it "does not expose password_digest" do
        get "/accounts/#{account.id}/users"

        u = response.parsed_body["users"].first
        expect(u).not_to have_key("password_digest")
        expect(u).not_to have_key("remember_token_digest")
      end

      it "returns 403 for a different account" do
        other = create(:account)
        get "/accounts/#{other.id}/users"
        expect(response).to have_http_status(:forbidden)
      end
    end

    describe "GET /accounts/:account_id/users/:id" do
      it "returns the user" do
        get "/accounts/#{account.id}/users/#{user.id}"

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["user"]["id"]).to eq(user.id)
      end

      it "returns 404 for an unknown user" do
        get "/accounts/#{account.id}/users/99999"
        expect(response).to have_http_status(:not_found)
      end
    end

    describe "POST /accounts/:account_id/users" do
      it "creates a user" do
        post "/accounts/#{account.id}/users",
          params: { user: { name: "New Teammate", email: "new@example.com", password: "secret123", password_confirmation: "secret123" } }

        expect(response).to have_http_status(:created)
        body = response.parsed_body
        expect(body["user"]["name"]).to eq("New Teammate")
        expect(body["user"]["email"]).to eq("new@example.com")
        expect(body["user"]).not_to have_key("password_digest")
      end

      it "returns 422 when required fields are missing" do
        post "/accounts/#{account.id}/users", params: { user: { name: "", email: "" } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["errors"]).to be_present
      end
    end

    describe "PATCH /accounts/:account_id/users/:id" do
      it "updates the user name" do
        patch "/accounts/#{account.id}/users/#{user.id}",
          params: { user: { name: "Updated Name" } }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["user"]["name"]).to eq("Updated Name")
      end

      it "returns 404 for an unknown user" do
        patch "/accounts/#{account.id}/users/99999", params: { user: { name: "X" } }
        expect(response).to have_http_status(:not_found)
      end
    end

    describe "DELETE /accounts/:account_id/users/:id" do
      it "deletes another user" do
        other_user = create(:user, account: account)
        delete "/accounts/#{account.id}/users/#{other_user.id}"

        expect(response).to have_http_status(:no_content)
        expect(User.find_by(id: other_user.id)).to be_nil
      end

      it "returns 422 when trying to remove yourself" do
        delete "/accounts/#{account.id}/users/#{user.id}"

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["error"]).to match(/cannot remove your own/)
      end

      it "returns 404 for an unknown user" do
        delete "/accounts/#{account.id}/users/99999"
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  context "when signed out" do
    it "returns 401" do
      get "/accounts/#{account.id}/users"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
