# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Draft approval UI", type: :request do
  let(:account) { create(:account) }
  let!(:user) { create(:user, account: account) }
  let!(:booking_request) { create(:booking_request, account: account) }
  let!(:draft) { create(:draft, account: account, booking_request: booking_request, status: "pending_review") }

  before { post "/login", params: {email: user.email, password: "password123"} }

  describe "GET /booking_requests/:id" do
    it "shows pending drafts on the detail page" do
      get "/booking_requests/#{booking_request.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(draft.body)
      expect(response.body).to include("pending_review")
    end
  end

  describe "POST /booking_requests/:booking_request_id/drafts/:id/approve" do
    it "transitions draft to approved and redirects" do
      post "/booking_requests/#{booking_request.id}/drafts/#{draft.id}/approve"

      expect(response).to have_http_status(:redirect)
      expect(draft.reload.status).to eq("approved")
    end

    it "returns 404 for another account's draft" do
      other_draft = create(:draft, status: "pending_review")
      post "/booking_requests/#{other_draft.booking_request.id}/drafts/#{other_draft.id}/approve"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /booking_requests/:booking_request_id/drafts/:id/reject" do
    it "transitions draft to rejected and redirects" do
      post "/booking_requests/#{booking_request.id}/drafts/#{draft.id}/reject"

      expect(response).to have_http_status(:redirect)
      expect(draft.reload.status).to eq("rejected")
    end
  end

  describe "when signed out" do
    before { delete "/logout" }

    it "redirects approve to login" do
      post "/booking_requests/#{booking_request.id}/drafts/#{draft.id}/approve"
      expect(response).to have_http_status(:redirect)
      expect(response.location).to include("/login")
    end
  end
end
