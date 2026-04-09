module BookingRequests
  class Transition
    class InvalidTransition < StandardError; end

    ALLOWED_TRANSITIONS = {
      "pending" => %w[reviewing confirmed cancelled],
      "reviewing" => %w[pending confirmed rejected cancelled],
      "confirmed" => %w[cancelled],
      "rejected" => %w[cancelled],
      "cancelled" => []
    }.freeze

    def self.call(booking_request:, to:, metadata: {})
      new(booking_request: booking_request, to: to, metadata: metadata).call
    end

    def initialize(booking_request:, to:, metadata: {})
      @booking_request = booking_request
      @to = to.to_s
      @metadata = metadata
    end

    def call
      from = booking_request.status

      validate!(from)

      booking_request.update!(status: to)

      EventLog.create!(
        account: booking_request.account,
        event_type: "booking_request.status_changed",
        subject_type: "BookingRequest",
        subject_id: booking_request.id,
        payload: { from: from, to: to }.merge(metadata)
      )

      booking_request
    end

    private

    attr_reader :booking_request, :to, :metadata

    def validate!(from)
      allowed = ALLOWED_TRANSITIONS.fetch(from, [])
      unless allowed.include?(to)
        raise InvalidTransition, "Cannot transition from '#{from}' to '#{to}'"
      end
    end
  end
end
