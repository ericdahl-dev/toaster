# frozen_string_literal: true

module BookingRequests
  class VenueRagRetriever
    TOP_K = 5

    def self.call(venue:, query:)
      new(venue:, query:).call
    end

    def initialize(venue:, query:)
      @venue = venue
      @query = query
    end

    def call
      return [] if ENV["OPENAI_API_KEY"].blank?

      chunks = venue.venue_documents.where(status: :ready)
        .joins(:venue_chunks)
        .where.not(venue_chunks: { embedding: nil })

      return [] unless chunks.exists?

      query_embedding = VenueEmbedder.embed(query)
      return [] if query_embedding.nil?

      VenueChunk
        .joins(:venue_document)
        .where(venue_documents: { venue_id: venue.id, status: "ready" })
        .nearest_neighbors(:embedding, query_embedding, distance: :cosine)
        .limit(TOP_K)
        .pluck(:content)
    end

    private

    attr_reader :venue, :query
  end
end
