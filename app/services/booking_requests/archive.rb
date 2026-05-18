# frozen_string_literal: true

module BookingRequests
  class Archive
    def self.call(booking_request:, metadata: {})
      new(booking_request: booking_request, metadata: metadata).call
    end

    def initialize(booking_request:, metadata: {})
      @booking_request = booking_request
      @metadata = metadata
    end

    def call
      return booking_request if booking_request.archived?

      booking_request.update!(archived_at: Time.current)

      EventLog.create!(
        account: booking_request.account,
        event_type: "booking_request.archived",
        subject_type: "BookingRequest",
        subject_id: booking_request.id,
        payload: metadata.except(:distinct_id).merge(source: "manual").stringify_keys
      )

      capture_telemetry("booking_request_archived", source: "manual")

      booking_request
    end

    private

    attr_reader :booking_request, :metadata

    def capture_telemetry(event, **properties)
      distinct_id = metadata[:distinct_id] || "account_#{booking_request.account_id}"
      Telemetry.capture(
        distinct_id: distinct_id,
        event: event,
        properties: {
          booking_request_id: booking_request.id,
          account_id: booking_request.account_id,
          **properties
        }
      )
    end
  end
end
