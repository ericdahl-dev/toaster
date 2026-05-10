# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Venues HTML", type: :request do
  let(:account) { create(:account) }
  let!(:user) { create(:user, account: account) }

  describe "GET /venues" do
    context "when signed in" do
      before { sign_in user }

      it "renders the list" do
        create(:venue, account: account, name: "Grand Hall")

        get "/venues"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Grand Hall")
      end

      it "does not show venues from other accounts" do
        other = create(:venue, name: "Other Venue")
        get "/venues"

        expect(response.body).not_to include(other.name)
      end
    end

    context "when signed out" do
      it "redirects to login" do
        get "/venues"
        expect(response).to have_http_status(:redirect)
        expect(response.location).to include("/login")
      end
    end
  end

  describe "GET /venues/new" do
    context "when signed in" do
      before { sign_in user }

      it "renders the form" do
        get "/venues/new"
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Add Venue")
      end
    end
  end

  describe "POST /venues" do
    context "when signed in" do
      before { sign_in user }

      it "creates a venue and redirects" do
        post "/venues", params: { venue: { name: "The Loft" } }

        expect(response).to have_http_status(:redirect)
        expect(Venue.where(account: account, name: "The Loft")).to exist
      end

      it "saves address and capacity" do
        post "/venues", params: { venue: { name: "The Loft", address: "123 Main St", capacity: 80 } }

        venue = Venue.find_by!(name: "The Loft")
        expect(venue.address).to eq("123 Main St")
        expect(venue.capacity).to eq(80)
      end

      it "re-renders with errors on blank name" do
        post "/venues", params: { venue: { name: "" } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Add Venue")
      end
    end
  end

  describe "GET /venues/:id/edit" do
    let!(:venue) { create(:venue, account: account) }

    context "when signed in" do
      before { sign_in user }

      it "renders the edit form" do
        get "/venues/#{venue.id}/edit"
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Edit Venue")
      end

      it "returns 404 for another account's venue" do
        other = create(:venue)
        get "/venues/#{other.id}/edit"
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PATCH /venues/:id" do
    let!(:venue) { create(:venue, account: account, name: "Old Name") }

    context "when signed in" do
      before { sign_in user }

      it "updates the venue and redirects" do
        patch "/venues/#{venue.id}", params: { venue: { name: "New Name" } }

        expect(response).to have_http_status(:redirect)
        expect(venue.reload.name).to eq("New Name")
      end

      it "updates address and capacity" do
        patch "/venues/#{venue.id}", params: { venue: { address: "999 Oak Ave", capacity: 200 } }

        venue.reload
        expect(venue.address).to eq("999 Oak Ave")
        expect(venue.capacity).to eq(200)
      end

      it "creates nested venue spaces" do
        patch "/venues/#{venue.id}", params: {
          venue: {
            venue_spaces_attributes: [
              { name: "Rooftop", capacity_seated: 40, capacity_reception: 150 }
            ]
          }
        }

        expect(response).to have_http_status(:redirect)
        expect(venue.venue_spaces.reload.size).to eq(1)
        expect(venue.venue_spaces.first.name).to eq("Rooftop")
      end

      it "destroys a venue space when _destroy is 1" do
        space = create(:venue_space, venue: venue, name: "Rooftop")
        patch "/venues/#{venue.id}", params: {
          venue: {
            venue_spaces_attributes: [ { id: space.id, _destroy: "1" } ]
          }
        }

        expect(VenueSpace.find_by(id: space.id)).to be_nil
      end
    end
  end

  describe "DELETE /venues/:id" do
    let!(:venue) { create(:venue, account: account) }

    context "when signed in" do
      before { sign_in user }

      it "deletes the venue and redirects" do
        delete "/venues/#{venue.id}"

        expect(response).to have_http_status(:redirect)
        expect(Venue.find_by(id: venue.id)).to be_nil
      end

      it "returns 404 for another account's venue" do
        other = create(:venue)
        delete "/venues/#{other.id}"
        expect(response).to have_http_status(:not_found)
      end

      it "redirects with alert when booking requests exist" do
        create(:booking_request, account: account, venue: venue)

        delete "/venues/#{venue.id}"

        expect(response).to have_http_status(:redirect)
        follow_redirect!
        expect(response.body).to include("booking requests")
        expect(Venue.find_by(id: venue.id)).not_to be_nil
      end
    end
  end
end
