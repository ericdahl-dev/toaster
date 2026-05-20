# frozen_string_literal: true

require "rails_helper"

RSpec.describe BookingRequests::InboundContext do
  describe ".prepare_text" do
    it "strips quoted reply headers from body_text" do
      inbox_message = build_stubbed(:inbox_message,
        body_text: "Hello\n\nOn Mon, 1 Jan wrote:\n> old stuff")

      result = described_class.prepare_text(inbox_message)

      expect(result).to eq("Hello")
    end

    it "returns empty string when body_text is blank" do
      inbox_message = build_stubbed(:inbox_message, body_text: nil)

      result = described_class.prepare_text(inbox_message)

      expect(result).to eq("")
    end
  end

  describe ".venue_chunks" do
    it "returns empty array when venue is nil" do
      result = described_class.venue_chunks(venue: nil, text: "Hi")

      expect(result).to eq([])
    end

    it "delegates to VenueRagRetriever with the provided text as query" do
      venue = build_stubbed(:venue)
      query_text = "stripped body"

      allow(BookingRequests::VenueKnowledge).to receive(:for)
        .with(venue: venue, query: "subject #{query_text}")
        .and_return(["chunk1"])

      result = described_class.venue_chunks(venue: venue, text: query_text, subject: "subject")

      expect(result).to eq(["chunk1"])
    end

    it "uses stripped text (not raw body) for the RAG query" do
      venue = build_stubbed(:venue)
      stripped = "Hello"

      expect(BookingRequests::VenueKnowledge).to receive(:for)
        .with(venue: venue, query: include(stripped))
        .and_return([])

      described_class.venue_chunks(venue: venue, text: stripped, subject: "Test")
    end
  end
end
