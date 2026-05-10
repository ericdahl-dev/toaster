module BookingRequests
  class Reconcile
    REVIEW_TASK_TITLE = "Review and qualify booking request"

    def self.call(inbox_message:, venue: nil)
      new(inbox_message: inbox_message, venue: venue).call
    end

    def initialize(inbox_message:, venue: nil)
      @inbox_message = inbox_message
      @venue = venue
    end

    def call
      ActiveRecord::Base.transaction do
        is_new = !BookingRequest.exists?(source_inbox_message: inbox_message)

        result = BookingRequests::Extract.call(inbox_message: inbox_message)
        return nil if result.nil?

        booking_request = result.booking_request

        assign_venue(booking_request)
        log_reconciliation(booking_request, is_new: is_new)
        create_review_task(booking_request) if booking_request.reviewing?
        generate_draft(booking_request) if is_new

        booking_request
      end
    end

    private

    attr_reader :inbox_message, :venue

    def assign_venue(booking_request)
      return if venue.nil?
      return if booking_request.venue_id.present?

      booking_request.update_column(:venue_id, venue.id)
    end

    def log_reconciliation(booking_request, is_new:)
      EventLog.create!(
        account: booking_request.account,
        event_type: is_new ? "booking_request.created" : "booking_request.updated",
        subject_type: "BookingRequest",
        subject_id: booking_request.id,
        payload: {
          status: booking_request.status,
          missing_fields: booking_request.missing_fields,
          review_reasons: booking_request.review_reasons
        }
      )
    end

    def create_review_task(booking_request)
      return if booking_request.tasks.open.exists?

      Task.create!(
        account: booking_request.account,
        booking_request: booking_request,
        title: REVIEW_TASK_TITLE,
        status: "open"
      )
    end

    def generate_draft(booking_request)
      return if booking_request.drafts.exists?

      venue_chunks = venue.present? ? VenueRagRetriever.call(venue: venue, query: "#{inbox_message.subject} #{inbox_message.body_text}") : []

      body = DraftWriter.new(account: booking_request.account, booking_request:, venue_chunks:).call(
        subject: inbox_message.subject,
        body_text: EmailBody::Strip.call(inbox_message.body_text)
      )

      Draft.create!(account: booking_request.account, booking_request:, body:, status: :pending_review)
    end
  end
end
