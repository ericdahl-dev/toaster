module BookingRequests
  class Reconcile
    REVIEW_TASK_TITLE = "Review and qualify booking request"

    Result = Struct.new(:booking_request, :draft_created, keyword_init: true)

    def self.call(inbox_message:, venue: nil, inbox_message_created: false)
      new(inbox_message: inbox_message, venue: venue, inbox_message_created: inbox_message_created).call
    end

    def initialize(inbox_message:, venue: nil, inbox_message_created: false)
      @inbox_message = inbox_message
      @venue = venue
      @inbox_message_created = inbox_message_created
    end

    def call
      ActiveRecord::Base.transaction do
        locked_booking_request = BookingRequests::ExtractionLock.booking_request_for(inbox_message)

        if locked_booking_request
          BookingRequests::Persist.record_inbound(
            inbox_message: inbox_message,
            booking_request: locked_booking_request
          )
          booking_request = locked_booking_request
          extraction_locked = true
        else
          extract_result = BookingRequests::Extract.call(inbox_message: inbox_message, venue: venue)
          return nil if extract_result.nil?

          booking_request = extract_result.booking_request
          extraction_locked = false
        end

        is_new = !extraction_locked && booking_request.previous_changes.key?("id")

        unarchive_on_inbound(booking_request)
        assign_venue(booking_request)

        if extraction_locked
          log_inbound_recorded(booking_request)
          draft_created = false
        else
          log_reconciliation(booking_request, is_new: is_new)
          create_review_task(booking_request) if booking_request.reviewing?
          draft_created = generate_draft(booking_request)
        end

        Result.new(booking_request: booking_request, draft_created: draft_created)
      end
    end

    private

    attr_reader :inbox_message, :venue, :inbox_message_created

    def unarchive_on_inbound(booking_request)
      return unless inbox_message_created
      return unless inbox_message.inbound?
      return unless booking_request.archived?

      BookingRequests::Unarchive.call(
        booking_request: booking_request,
        metadata: { source: "inbound" }
      )
    end

    def assign_venue(booking_request)
      return if venue.nil?
      return if booking_request.venue_id.present?

      booking_request.update_column(:venue_id, venue.id)
    end

    def log_inbound_recorded(booking_request)
      EventLog.create!(
        account: booking_request.account,
        event_type: "booking_request.inbound_recorded",
        subject_type: "BookingRequest",
        subject_id: booking_request.id,
        payload: {
          status: booking_request.status,
          extraction_locked: true,
          inbox_message_id: inbox_message.id
        }
      )
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
      return false if booking_request.drafts.pending_review.exists?

      venue_chunks = venue.present? ? VenueRagRetriever.call(venue: venue, query: "#{inbox_message.subject} #{inbox_message.body_text}") : []
      thread_history = build_thread_history(booking_request)

      body = DraftWriter.new(account: booking_request.account, booking_request:, venue_chunks:).call(
        subject: inbox_message.subject,
        body_text: EmailBody::Strip.call(inbox_message.body_text),
        thread_history:
      )

      Draft.create!(account: booking_request.account, booking_request:, body:, status: :pending_review)
      true
    end

    def build_thread_history(booking_request)
      inbound_turns = booking_request.messages.where(direction: :inbound).map do |msg|
        { role: "user", content: msg.body_text.to_s, timestamp: msg.sent_at }
      end

      outbound_turns = booking_request.drafts
        .where(status: %w[approved modified sent])
        .map do |draft|
          { role: "assistant", content: draft.body.to_s, timestamp: draft.created_at }
        end

      (inbound_turns + outbound_turns)
        .sort_by { |t| t[:timestamp] || Time.at(0) }
        .map { |t| { role: t[:role], content: t[:content] } }
    end
  end
end
