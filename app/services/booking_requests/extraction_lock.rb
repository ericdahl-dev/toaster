# frozen_string_literal: true

module BookingRequests
  module ExtractionLock
    module_function

    def terminal?(booking_request)
      booking_request&.confirmed? || booking_request&.cancelled?
    end

    def booking_request_for(inbox_message)
      thread = inbox_message.account.conversation_threads.find_by(
        provider_thread_id: thread_id_for(inbox_message)
      )
      booking_request = thread&.booking_requests&.first
      terminal?(booking_request) ? booking_request : nil
    end

    def thread_id_for(inbox_message)
      "#{inbox_message.provider}:#{inbox_message.provider_thread_id.presence || inbox_message.provider_message_id}"
    end
  end
end
