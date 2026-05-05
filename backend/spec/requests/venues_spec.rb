# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Venues", type: :request do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let!(:venue) { create(:venue, account: account) }

  context "when signed in" do
    before { sign_in_as(user) }

    describe "GET /accounts/:account_id/venues" do
      it "returns all venues for the account" do
        get "/accounts/#{account.id}/venues"

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["venues"].length).to eq(1)
        expect(body["venues"].first["name"]).to eq(venue.name)
      end

      it "returns 403 for a different account" do
        other = create(:account)
        get "/accounts/#{other.id}/venues"
        expect(response).to have_http_status(:forbidden)
      end
    end

    describe "GET /accounts/:account_id/venues/:id" do
      it "returns the venue" do
        get "/accounts/#{account.id}/venues/#{venue.id}"

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["venue"]["id"]).to eq(venue.id)
      end

      it "returns 404 for an unknown venue" do
        get "/accounts/#{account.id}/venues/99999"
        expect(response).to have_http_status(:not_found)
      end
    end

    describe "POST /accounts/:account_id/venues" do
      it "creates a venue" do
        post "/accounts/#{account.id}/venues",
          params: { venue: { name: "Grand Hall", address: "1 Park Ave", capacity: 200 } }

        expect(response).to have_http_status(:created)
        body = response.parsed_body
        expect(body["venue"]["name"]).to eq("Grand Hall")
        expect(body["venue"]["capacity"]).to eq(200)
      end

      it "returns 422 when name is blank" do
        post "/accounts/#{account.id}/venues", params: { venue: { name: "" } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["errors"]).to be_present
      end

      it "returns 403 for a different account" do
        post "/accounts/99999/venues", params: { venue: { name: "X" } }
        expect(response).to have_http_status(:forbidden)
      end
    end

    describe "PATCH /accounts/:account_id/venues/:id" do
      it "updates the venue" do
        patch "/accounts/#{account.id}/venues/#{venue.id}",
          params: { venue: { name: "New Name" } }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["venue"]["name"]).to eq("New Name")
      end

      it "returns 404 for an unknown venue" do
        patch "/accounts/#{account.id}/venues/99999", params: { venue: { name: "X" } }
        expect(response).to have_http_status(:not_found)
      end
    end

    describe "DELETE /accounts/:account_id/venues/:id" do
      it "deletes the venue" do
        delete "/accounts/#{account.id}/venues/#{venue.id}"

        expect(response).to have_http_status(:no_content)
        expect(Venue.find_by(id: venue.id)).to be_nil
      end

      it "returns 404 for an unknown venue" do
        delete "/accounts/#{account.id}/venues/99999"
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  context "when signed out" do
    it "returns 401" do
      get "/accounts/#{account.id}/venues"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
