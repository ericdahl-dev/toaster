# frozen_string_literal: true

module BookingRequests
  class LlmExtractor
    include LlmCall

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
    RUN_TYPE = "extraction"
    TEMPERATURE = 0.2

    def parse_result(raw)
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

    private

    def build_prompt(subject:, body_text:)
      base = "Subject: #{subject}\n\nBody:\n#{body_text}"
      chunks = retrieve_venue_chunks(subject:, body_text:)
      @_rag_chunks = chunks
      return base if chunks.empty?

      venue_context = "Venue Context:\n#{chunks.map { |c| "- #{c}" }.join("\n")}"
      "#{venue_context}\n\n#{base}"
    end

    def extra_run_attrs
      {rag_chunk_count: @_rag_chunks&.size || 0}
    end

    def retrieve_venue_chunks(subject:, body_text:)
      return [] if booking_request&.venue.nil?

      VenueRagRetriever.call(
        venue: booking_request.venue,
        query: "#{subject} #{body_text}"
      )
    end

    def parse_date(value)
      return nil if value.blank?
      Date.parse(value)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
