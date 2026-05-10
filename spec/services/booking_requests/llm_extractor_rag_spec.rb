# frozen_string_literal: true

require "rails_helper"

RSpec.describe BookingRequests::LlmExtractor do
  let(:account) { create(:account) }
  let(:venue) { create(:venue, account:) }
  let(:booking_request) { create(:booking_request, account:, venue:) }

  subject(:extractor) { described_class.new(account:, booking_request:) }

  let(:base_llm_response) do
    {
      "event_date" => "2026-06-14",
      "headcount" => 40,
      "budget" => 500.0,
      "start_time" => "7:00 PM",
      "celebration_type" => "birthday",
      "confidence" => 0.95,
      "notes" => nil
    }
  end

  before do
    stub_const("ENV", ENV.to_h.merge("OPENAI_API_KEY" => "test-key"))
    allow(extractor).to receive(:call_openai).and_return(base_llm_response)
  end

  describe "venue RAG context injection" do
    context "when venue has chunks" do
      let!(:doc) { create(:venue_document, venue:, status: :ready) }
      let!(:chunk) { create(:venue_chunk, venue_document: doc, content: "The Rooftop holds 150 guests.") }

      before do
        allow(BookingRequests::VenueRagRetriever).to receive(:call).and_return(["The Rooftop holds 150 guests."])
      end

      it "calls VenueRagRetriever with the venue and query" do
        extractor.call(subject: "Party inquiry", body_text: "40 guests")
        expect(BookingRequests::VenueRagRetriever).to have_received(:call).with(
          venue:,
          query: a_string_including("Party inquiry")
        )
      end

      it "includes chunk content in the prompt" do
        extractor.call(subject: "Party inquiry", body_text: "40 guests")
        run = AiRun.last
        expect(run.prompt).to include("The Rooftop holds 150 guests.")
      end

      it "stores rag_chunk_count on AiRun" do
        extractor.call(subject: "Party inquiry", body_text: "40 guests")
        run = AiRun.last
        expect(run.rag_chunk_count).to eq(1)
      end
    end

    context "when booking_request has no venue" do
      let(:booking_request) { create(:booking_request, account:, venue: nil) }

      it "does not call VenueRagRetriever" do
        allow(BookingRequests::VenueRagRetriever).to receive(:call)
        extractor.call(subject: "Party inquiry", body_text: "40 guests")
        expect(BookingRequests::VenueRagRetriever).not_to have_received(:call)
      end

      it "stores rag_chunk_count 0 on AiRun" do
        extractor.call(subject: "Party inquiry", body_text: "40 guests")
        expect(AiRun.last.rag_chunk_count).to eq(0)
      end
    end

    context "when venue has no chunks" do
      before do
        allow(BookingRequests::VenueRagRetriever).to receive(:call).and_return([])
      end

      it "stores rag_chunk_count 0 on AiRun" do
        extractor.call(subject: "Party inquiry", body_text: "40 guests")
        expect(AiRun.last.rag_chunk_count).to eq(0)
      end

      it "does not include venue context header in prompt" do
        extractor.call(subject: "Party inquiry", body_text: "40 guests")
        expect(AiRun.last.prompt).not_to include("Venue Context")
      end
    end
  end
end
