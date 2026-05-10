# frozen_string_literal: true

module BookingRequests
  class Classifier
    include LlmCall

    MODEL = "gpt-4o-mini"
    PROMPT_VERSION = "classifier-v1"
    SYSTEM_PROMPT = <<~PROMPT
      You are an assistant that determines whether an inbound email is a genuine venue booking inquiry.
      Respond with JSON: {"booking_request": true} or {"booking_request": false}.
      Return false for: out-of-office replies, automatic replies, spam, newsletters, and any message
      that is not a human requesting to book or inquire about booking a venue event.
    PROMPT
    RUN_TYPE = "classifier"
    TEMPERATURE = 0

    def parse_result(raw)
      raw["booking_request"] == true
    end
  end
end
