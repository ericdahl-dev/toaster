# frozen_string_literal: true

module BookingRequests
  # Retrieves relevant venue knowledge chunks for an AI prompt.
  #
  # Returns an empty array when:
  #   - venue is nil (no knowledge source to query)
  #   - OPENAI_API_KEY is blank (degrades gracefully; caller gets no context)
  #   - the venue has no indexed chunks or the embedding query returns nothing
  #
  # This is the single entry point for RAG at AI call sites. Do not call
  # VenueRagRetriever directly from services or jobs.
  module VenueKnowledge
    def self.for(venue:, query:)
      return [] if venue.nil?

      VenueRagRetriever.call(venue: venue, query: query)
    end
  end
end
