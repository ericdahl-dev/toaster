# frozen_string_literal: true

module Ops
  module BookingPayload
    extend ActiveSupport::Concern

    private

    def booking_request_summary(booking_request)
      return nil unless booking_request

      {
        id: booking_request.id,
        status: booking_request.status
      }
    end

    def booking_request_detail(booking_request)
      return nil unless booking_request

      pending_draft = booking_request.drafts.find_by(status: :pending_review)

      {
        id: booking_request.id,
        status: booking_request.status,
        event_date: booking_request.event_date,
        headcount: booking_request.headcount,
        budget_cents: booking_request.budget_cents,
        missing_fields: booking_request.missing_fields,
        review_reasons: booking_request.review_reasons,
        extraction_snapshot: booking_request.extraction_snapshot,
        pending_draft: pending_draft ? {id: pending_draft.id, body: pending_draft.body} : nil
      }
    end
  end
end
