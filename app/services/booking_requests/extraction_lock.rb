# frozen_string_literal: true

module BookingRequests
  module ExtractionLock
    module_function

    def terminal?(booking_request)
      return false if booking_request.nil?

      booking_request.confirmed? || booking_request.cancelled?
    end

    def booking_request_for(inbox_message)
      booking_request = ThreadLookup.booking_request_for(inbox_message)
      terminal?(booking_request) ? booking_request : nil
    end
  end
end
