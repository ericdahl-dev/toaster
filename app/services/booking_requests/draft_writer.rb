# frozen_string_literal: true

module BookingRequests
  class DraftWriter
    include LlmCall

    MODEL = "gpt-4o-mini"
    PROMPT_VERSION = "draft-writer-v1"
    SYSTEM_PROMPT = <<~PROMPT
      You are a professional venue coordinator writing a warm, concise reply to a booking inquiry.
      Your reply should:
        - Thank the guest for their interest
        - Acknowledge the key details they provided (date, headcount, occasion, budget if mentioned)
        - Ask for any missing key details naturally (date, headcount, occasion type, budget if not provided)
        - Briefly mention the venue's availability check will follow
        - Be friendly and professional — 3 to 5 sentences, plain text, no markdown, no subject line
      Respond with a single JSON field: { "body": "<reply text>" }
    PROMPT
    RUN_TYPE = "draft_writer"
    TEMPERATURE = 0.7

    def initialize(account:, booking_request: nil, client: nil, venue_chunks: [])
      super(account:, booking_request:, client:)
      @venue_chunks = venue_chunks
    end

    def call(subject:, body_text:, thread_history: [])
      if thread_history.any?
        @pending_messages = build_thread_messages(subject:, body_text:, thread_history:)
      end
      super(subject:, body_text:)
    ensure
      @pending_messages = nil
    end

    def parse_result(raw)
      raw["body"].to_s.strip
    end

    private

    attr_reader :venue_chunks

    def build_thread_messages(subject:, body_text:, thread_history:)
      final_user_content = build_prompt(subject:, body_text:)
      [
        { role: "system", content: self.class::SYSTEM_PROMPT },
        *thread_history,
        { role: "user", content: final_user_content }
      ]
    end

    def call_openai(prompt)
      messages = @pending_messages || [
        { role: "system", content: self.class::SYSTEM_PROMPT },
        { role: "user", content: prompt }
      ]

      response = client.chat(
        parameters: {
          model: self.class::MODEL,
          response_format: { type: "json_object" },
          messages: messages,
          temperature: self.class::TEMPERATURE
        }
      )
      JSON.parse(response.dig("choices", 0, "message", "content"))
    end

    def build_prompt(subject:, body_text:)
      base = "Subject: #{subject}\n\nBody:\n#{body_text}"
      return base if venue_chunks.empty?

      venue_context = "Venue Context:\n#{venue_chunks.map { |c| "- #{c}" }.join("\n")}"
      "#{venue_context}\n\n#{base}"
    end

    def extra_run_attrs
      { rag_chunk_count: venue_chunks.size }
    end
  end
end
