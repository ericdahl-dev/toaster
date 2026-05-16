# frozen_string_literal: true

module BookingRequests
  module LlmCall
    ConfigurationError = Class.new(StandardError)

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def call(account:, booking_request: nil, subject:, body_text:, client: nil)
        new(account:, booking_request:, client:).call(subject:, body_text:)
      end
    end

    def initialize(account:, booking_request: nil, client: nil)
      @account = account
      @booking_request = booking_request
      @client = client || build_client
    end

    def call(subject:, body_text:)
      prompt = build_prompt(subject:, body_text:)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      raw = call_openai(prompt)
      latency_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).to_i

      persist_run(prompt:, result: raw, latency_ms:, extra_attrs: extra_run_attrs)

      parse_result(raw)
    end

    private

    attr_reader :account, :booking_request, :client

    def build_client
      raise ConfigurationError, "OPENAI_API_KEY is not set" if ENV["OPENAI_API_KEY"].blank?

      OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])
    end

    def build_prompt(subject:, body_text:)
      "Subject: #{subject}\n\nBody:\n#{body_text}"
    end

    def extra_run_attrs
      {}
    end

    def call_openai(prompt)
      response = client.chat(
        parameters: {
          model: self.class::MODEL,
          response_format: { type: "json_object" },
          messages: [
            { role: "system", content: self.class::SYSTEM_PROMPT },
            { role: "user", content: prompt }
          ],
          temperature: self.class::TEMPERATURE
        }
      )
      @last_usage = response["usage"]
      JSON.parse(response.dig("choices", 0, "message", "content"))
    end

    def persist_run(prompt:, result:, latency_ms:, extra_attrs: {})
      input_tokens = @last_usage&.dig("prompt_tokens")
      output_tokens = @last_usage&.dig("completion_tokens")
      cost = AiCostCalculator.openai_cost_cents(
        model: self.class::MODEL,
        input_tokens: input_tokens || 0,
        output_tokens: output_tokens || 0
      )

      AiRun.create!(
        account:,
        booking_request:,
        run_type: self.class::RUN_TYPE,
        llm_model: self.class::MODEL,
        prompt_version: self.class::PROMPT_VERSION,
        prompt:,
        response: result.to_json,
        latency_ms:,
        input_tokens:,
        output_tokens:,
        estimated_cost_cents: cost,
        **extra_attrs
      )
    end
  end
end
