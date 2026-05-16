# frozen_string_literal: true

require "rails_helper"

RSpec.describe "InboxFilters", type: :request do
  let(:account) { create(:account) }
  let!(:user) { create(:user, account: account) }
  let(:connection) { create(:imap_connection, account: account) }
  let(:venue) { create(:venue, account: account) }

  describe "POST /mail_connections/:mail_connection_id/inbox_filters" do
    context "when signed in" do
      before { sign_in user }

      it "creates a filter when venue belongs to the current account" do
        expect {
          post "/mail_connections/#{connection.id}/inbox_filters",
            params: { inbox_filter: { keyword: "wedding", venue_id: venue.id } }
        }.to change(InboxFilter, :count).by(1)

        expect(response).to have_http_status(:redirect)
      end

      it "returns 404 when venue_id belongs to another account" do
        other_venue = create(:venue)

        expect {
          post "/mail_connections/#{connection.id}/inbox_filters",
            params: { inbox_filter: { keyword: "wedding", venue_id: other_venue.id } }
        }.not_to change(InboxFilter, :count)

        expect(response).to have_http_status(:not_found)
      end

      it "returns 404 when venue_id is absent" do
        expect {
          post "/mail_connections/#{connection.id}/inbox_filters",
            params: { inbox_filter: { keyword: "wedding" } }
        }.not_to change(InboxFilter, :count)

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when signed out" do
      it "redirects to login" do
        post "/mail_connections/#{connection.id}/inbox_filters",
          params: { inbox_filter: { keyword: "wedding", venue_id: venue.id } }

        expect(response).to have_http_status(:redirect)
        expect(response.location).to include("/login")
      end
    end
  end

  describe "DELETE /mail_connections/:mail_connection_id/inbox_filters/:id" do
    let!(:filter) { create(:inbox_filter, imap_connection: connection, venue: venue) }

    context "when signed in" do
      before { sign_in user }

      it "destroys the filter" do
        expect {
          delete "/mail_connections/#{connection.id}/inbox_filters/#{filter.id}"
        }.to change(InboxFilter, :count).by(-1)

        expect(response).to have_http_status(:redirect)
      end
    end
  end
end
