# frozen_string_literal: true

require "rails_helper"

RSpec.describe "BookingRequests HTML", type: :request do
  let(:account) { create(:account) }
  let!(:user) { create(:user, account: account) }
  let!(:booking_request) { create(:booking_request, account: account) }

  describe "GET /booking_requests" do
    context "when signed in" do
      before { sign_in user }

      it "renders the list" do
        get "/booking_requests"

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to match(%r{text/html})
        expect(response.body).to include("Booking Requests")
      end

      it "does not show requests from other accounts" do
        other = create(:booking_request)
        get "/booking_requests"

        expect(response.body).not_to include(other.contact.email)
      end
    end

    context "when signed out" do
      it "redirects to login" do
        get "/booking_requests"

        expect(response).to have_http_status(:redirect)
        expect(response.location).to include("/login")
      end
    end
  end

  describe "GET /booking_requests/:id" do
    context "when signed in" do
      before { sign_in user }

      it "renders the detail page" do
        get "/booking_requests/#{booking_request.id}"

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to match(%r{text/html})
        expect(response.body).to include(booking_request.status)
      end

      it "shows conversation thread when source_inbox_message present" do
        inbox_message = create(:inbox_message, account: account,
          subject: "Grand Hall booking inquiry",
          from_name: "Jane Doe",
          from_email: "jane@example.com",
          body_text: "Hi, I'd like to book your grand hall.")
        booking_request.update!(source_inbox_message: inbox_message)

        get "/booking_requests/#{booking_request.id}"

        expect(response.body).to include("Conversation")
        expect(response.body).to include("Grand Hall booking inquiry")
        expect(response.body).to include("Jane Doe")
        expect(response.body).to include("jane@example.com")
      end

      it "omits conversation section when source_inbox_message is nil and no messages" do
        booking_request.update!(source_inbox_message: nil)

        get "/booking_requests/#{booking_request.id}"

        expect(response.body).not_to include("Conversation")
      end

      it "shows qualification panel with fit_status badge and missing fields" do
        booking_request.update!(fit_status: "in_progress", missing_fields: %w[event_date headcount])

        get "/booking_requests/#{booking_request.id}"

        expect(response.body).to include("badge-in_progress")
        expect(response.body).to include("event_date")
        expect(response.body).to include("headcount")
      end

      it "shows all-collected indicator when missing_fields is empty and fit_status present" do
        booking_request.update!(fit_status: "qualified", missing_fields: [])

        get "/booking_requests/#{booking_request.id}"

        expect(response.body).to include("badge-qualified")
        expect(response.body).to include("All required info collected")
      end

      it "omits qualification panel when both fit_status and missing_fields are nil/empty" do
        booking_request.update!(fit_status: nil, missing_fields: [])

        get "/booking_requests/#{booking_request.id}"

        expect(response.body).not_to include("qualification-panel")
      end

      it "returns 404 for another account's request" do
        other = create(:booking_request)
        get "/booking_requests/#{other.id}"

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when signed out" do
      it "redirects to login" do
        get "/booking_requests/#{booking_request.id}"

        expect(response).to have_http_status(:redirect)
        expect(response.location).to include("/login")
      end
    end
  end

  describe "POST /booking_requests/:id/transition" do
    context "when signed in" do
      before { sign_in user }

      it "transitions to an allowed status and redirects" do
        post "/booking_requests/#{booking_request.id}/transition", params: { to: "reviewing" }

        expect(response).to have_http_status(:redirect)
        expect(booking_request.reload.status).to eq("reviewing")
      end

      it "redirects with alert on invalid transition" do
        booking_request.update!(status: "confirmed")
        post "/booking_requests/#{booking_request.id}/transition", params: { to: "pending" }

        expect(response).to have_http_status(:redirect)
        expect(booking_request.reload.status).to eq("confirmed")
      end

      it "returns 404 for another account's request" do
        other = create(:booking_request)
        post "/booking_requests/#{other.id}/transition", params: { to: "reviewing" }

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when signed out" do
      it "redirects to login" do
        post "/booking_requests/#{booking_request.id}/transition", params: { to: "reviewing" }
        expect(response).to have_http_status(:redirect)
        expect(response.location).to include("/login")
      end
    end
  end
end
