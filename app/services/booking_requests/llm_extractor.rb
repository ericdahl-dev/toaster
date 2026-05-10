# frozen_string_literal: true

module BookingRequests
  class LlmExtractor
    ConfigurationError = Class.new(StandardError)

    MODEL = "gpt-4o-mini"
    PROMPT_VERSION = "extractor-v1"
    SYSTEM_PROMPT = <<~PROMPT
      You are an assistant that extracts structured booking details from venue inquiry emails.
      Respond with JSON containing these fields:
        event_date        - ISO 8601 date string (YYYY-MM-DD) or null if not mentioned
        headcount         - integer number of guests or null if not mentioned
        budget            - float dollar amount (e.g. 500.0) or null if not mentioned
        start_time        - human-readable time string (e.g. "7:00 PM") or null if not mentioned
        celebration_type  - one of: birthday, anniversary, wedding, corporate, graduation, other, or null
        confidence        - float between 0 and 1 reflecting how complete and clear the request is
        notes             - any other relevant details as a short string, or null
    PROMPT

    def initialize(account:, booking_request: nil)
      @account = account
      @booking_request = booking_request
    end

    def call(subject:, body_text:)
      raise ConfigurationError, "OPENAI_API_KEY is not set" if ENV["OPENAI_API_KEY"].blank?

      prompt = build_prompt(subject:, body_text:)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      raw = call_openai(prompt)
      latency_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).to_i

      persist_run(prompt:, result: raw, latency_ms:)

      build_result(raw)
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
          temperature: 0.2
        }
      )
      JSON.parse(response.dig("choices", 0, "message", "content"))
    end

    def build_result(raw)
      {
        event_date: parse_date(raw["event_date"]),
        headcount: raw["headcount"],
        budget: raw["budget"],
        start_time: raw["start_time"],
        celebration_type: raw["celebration_type"],
        confidence: raw["confidence"],
        notes: raw["notes"]
      }
    end

    def parse_date(value)
      return nil if value.blank?
      Date.parse(value)
    rescue ArgumentError, TypeError
      nil
    end

    def persist_run(prompt:, result:, latency_ms:)
      AiRun.create!(
        account:,
        booking_request:,
        run_type: "extraction",
        llm_model: MODEL,
        prompt_version: PROMPT_VERSION,
        prompt:,
        response: result.to_json,
        latency_ms:
      )
    end
  end
end
