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

      it "shows first received and last activity from mail timestamps, not record created_at" do
        received = Time.zone.parse("2023-08-09 14:30")
        inbox = create(:inbox_message, account: account, received_at: received, subject: "Rooftop birthday")
        booking_request.update!(
          source_inbox_message: inbox,
          created_at: Time.zone.parse("2026-05-18 10:00"),
          updated_at: Time.zone.parse("2026-06-02 11:00")
        )
        thread = booking_request.conversation_thread
        thread.update!(subject: "Rooftop birthday")

        get "/booking_requests"

        expect(response.body).to include("First received")
        expect(response.body).to include("Last activity")
        expect(response.body).to include("9 Aug 2023")
        expect(response.body).to include("Rooftop birthday")
        expect(response.body).not_to include("18 May")
      end

      it "shows last activity direction on the list" do
        create(:message, account: account,
          conversation_thread: booking_request.conversation_thread,
          booking_request: booking_request,
          direction: :inbound,
          sent_at: Time.zone.parse("2026-05-18 15:00"))

        get "/booking_requests"

        expect(response.body).to include("From contact")
      end

      it "excludes archived booking requests from the default list" do
        booking_request.update!(archived_at: 1.hour.ago)
        other = create(:booking_request, account: account)

        get "/booking_requests"

        expect(response.body).to include(other.contact.email)
        expect(response.body).not_to include(booking_request.contact.email)
      end

      it "shows archived booking requests when show_archived=1" do
        booking_request.update!(archived_at: 1.hour.ago)

        get "/booking_requests", params: { show_archived: "1" }

        expect(response.body).to include(booking_request.contact.email)
        expect(response.body).to include("Show active")
      end

      it "marks secondary columns for mobile collapse" do
        get "/booking_requests"

        expect(response.body).to include("booking-requests-table")
        expect(response.body).to include('<th class="booking-requests-col--secondary">Venue</th>')
        expect(response.body).to include('<th class="booking-requests-col--secondary">Headcount</th>')
        expect(response.body).to include('class="dim booking-requests-col--secondary"')
        expect(response.body).to include("booking-request-thread-link")
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

      it "shows archive action when not archived" do
        get "/booking_requests/#{booking_request.id}"

        expect(response.body).to include("Archive")
      end

      it "shows restore action when archived" do
        booking_request.update!(archived_at: 1.hour.ago)

        get "/booking_requests/#{booking_request.id}"

        expect(response.body).to include("Restore to list")
      end

      context "intake panel" do
        it "renders intake panel when any intake field is present" do
          venue_space = create(:venue_space, venue: create(:venue, account: account))
          booking_request.update!(
            booking_type: "birthday party",
            duration: "2_hours",
            private_space_preference: "private",
            beverage_format: "hosted_tab",
            lead_recap: "Wants rooftop for 50 guests.",
            recommended_venue_space: venue_space
          )

          get "/booking_requests/#{booking_request.id}"

          expect(response.body).to include("intake-panel")
          expect(response.body).to include("birthday party")
          expect(response.body).to include(venue_space.name)
          expect(response.body).to include("Wants rooftop for 50 guests.")
        end

        it "omits intake panel when all intake fields are nil" do
          booking_request.update!(
            booking_type: nil,
            duration: nil,
            private_space_preference: nil,
            beverage_format: nil,
            lead_recap: nil,
            recommended_venue_space_id: nil
          )

          get "/booking_requests/#{booking_request.id}"

          expect(response.body).not_to include("intake-panel")
        end

        it "shows venue space name not ID" do
          venue_space = create(:venue_space, venue: create(:venue, account: account), name: "Rooftop Terrace")
          booking_request.update!(recommended_venue_space: venue_space)

          get "/booking_requests/#{booking_request.id}"

          expect(response.body).to include("Rooftop Terrace")
        end
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

  describe "POST /booking_requests/:id/archive" do
    context "when signed in" do
      before { sign_in user }

      it "archives the booking request and redirects to the list" do
        post "/booking_requests/#{booking_request.id}/archive"

        expect(response).to redirect_to(booking_requests_path)
        expect(booking_request.reload.archived_at).to be_present
      end

      it "returns 404 for another account's request" do
        other = create(:booking_request)
        post "/booking_requests/#{other.id}/archive"

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /booking_requests/:id/unarchive" do
    context "when signed in" do
      before { sign_in user }

      it "restores the booking request" do
        booking_request.update!(archived_at: 1.hour.ago)

        post "/booking_requests/#{booking_request.id}/unarchive"

        expect(response).to redirect_to(booking_request_path(booking_request))
        expect(booking_request.reload.archived_at).to be_nil
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
