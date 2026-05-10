# frozen_string_literal: true

module BookingRequests
  class Classifier
    ConfigurationError = Class.new(StandardError)

    MODEL = "gpt-4o-mini"
    PROMPT_VERSION = "classifier-v1"
    SYSTEM_PROMPT = <<~PROMPT
      You are an assistant that determines whether an inbound email is a genuine venue booking inquiry.
      Respond with JSON: {"booking_request": true} or {"booking_request": false}.
      Return false for: out-of-office replies, automatic replies, spam, newsletters, and any message
      that is not a human requesting to book or inquire about booking a venue event.
    PROMPT

    def initialize(account:, booking_request: nil)
      @account = account
      @booking_request = booking_request
    end

    def call(subject:, body_text:)
      raise ConfigurationError, "OPENAI_API_KEY is not set" if ENV["OPENAI_API_KEY"].blank?

      prompt = build_prompt(subject:, body_text:)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = call_openai(prompt)
      latency_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).to_i

      persist_run(prompt:, result:, latency_ms:)

      result["booking_request"] == true
    end

    private

    attr_reader :account, :booking_request

    def build_prompt(subject:, body_text:)
      "Subject: #{subject}\n\nBody:\n#{body_text}"
    end

    def call_openai(prompt)
      client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])
      response = client.chat(
        parameters: {
          model: MODEL,
          response_format: {type: "json_object"},
          messages: [
            {role: "system", content: SYSTEM_PROMPT},
            {role: "user", content: prompt}
          ],
          temperature: 0
        }
      )
      JSON.parse(response.dig("choices", 0, "message", "content"))
    end

    def persist_run(prompt:, result:, latency_ms:)
      AiRun.create!(
        account:,
        booking_request:,
        run_type: "classifier",
        llm_model: MODEL,
        prompt_version: PROMPT_VERSION,
        prompt:,
        response: result.to_json,
        latency_ms:
      )
    end
  end
end
