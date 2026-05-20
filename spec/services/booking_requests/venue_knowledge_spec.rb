# frozen_string_literal: true

require "rails_helper"

RSpec.describe BookingRequests::VenueKnowledge do
  describe ".for" do
    it "returns empty array when venue is nil" do
      result = described_class.for(venue: nil, query: "rooftop capacity")

      expect(result).to eq([])
    end

    it "returns empty array when OPENAI_API_KEY is blank (degrades gracefully)" do
      venue = build_stubbed(:venue)
      stub_const("ENV", ENV.to_h.merge("OPENAI_API_KEY" => ""))

      result = described_class.for(venue: venue, query: "rooftop capacity")

      expect(result).to eq([])
    end

    it "returns empty array when no ready chunks exist" do
      venue = build_stubbed(:venue)

      allow(BookingRequests::VenueRagRetriever).to receive(:call)
        .with(venue: venue, query: "rooftop capacity")
        .and_return([])

      result = described_class.for(venue: venue, query: "rooftop capacity")

      expect(result).to eq([])
    end

    it "returns content strings from the knowledge index" do
      venue = build_stubbed(:venue)
      chunks = ["We seat up to 200 guests.", "Rooftop access included."]

      allow(BookingRequests::VenueRagRetriever).to receive(:call)
        .with(venue: venue, query: "rooftop capacity")
        .and_return(chunks)

      result = described_class.for(venue: venue, query: "rooftop capacity")

      expect(result).to eq(chunks)
    end
  end
end
