module BookingRequests
  class Reconcile
    REVIEW_TASK_TITLE = "Review and qualify booking request"

    def self.call(inbox_message:, imap_connection: nil)
      new(inbox_message: inbox_message, imap_connection: imap_connection).call
    end

    def initialize(inbox_message:, imap_connection: nil)
      @inbox_message = inbox_message
      @imap_connection = imap_connection
    end

    def call
      ActiveRecord::Base.transaction do
        is_new = !BookingRequest.exists?(source_inbox_message: inbox_message)

        result = BookingRequests::Extract.call(inbox_message: inbox_message)
        booking_request = result.booking_request

        assign_venue(booking_request)
        log_reconciliation(booking_request, is_new: is_new)
        create_review_task(booking_request) if booking_request.reviewing?

        booking_request
      end
    end

    private

    attr_reader :inbox_message, :imap_connection

    def assign_venue(booking_request)
      return if imap_connection.nil?
      return if booking_request.venue_id.present?

      venue = InboxIngestion::FilterMatcher
        .new(imap_connection: imap_connection)
        .match(subject: inbox_message.subject)
      booking_request.update_column(:venue_id, venue.id) if venue
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
  end
end
