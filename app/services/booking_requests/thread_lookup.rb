# frozen_string_literal: true

module BookingRequests
  # Shared inbox-message → ConversationThread → BookingRequest resolution for Persist and ExtractionLock.
  module ThreadLookup
    module_function

    def conversation_thread_for(inbox_message)
      inbox_message.account.conversation_threads.find_by(
        provider_thread_id: ConversationThreading.canonical_id_for(inbox_message)
      )
    end

    def booking_request_for(inbox_message)
      booking_request_for_thread(conversation_thread_for(inbox_message))
    end

    def booking_request_for_thread(thread)
      thread&.booking_requests&.first
    end
  end
end
