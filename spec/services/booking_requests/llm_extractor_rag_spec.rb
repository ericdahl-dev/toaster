# frozen_string_literal: true

require "rails_helper"

RSpec.describe BookingRequests::LlmExtractor do
  let(:account) { create(:account) }
  let(:venue) { create(:venue, account:) }
  let(:booking_request) { create(:booking_request, account:, venue:) }

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

  def build_client(response = base_llm_response)
    client = double("OpenAI::Client")
    allow(client).to receive(:chat).and_return(
      { "choices" => [ { "message" => { "content" => response.to_json } } ] }
    )
    client
  end

  describe "venue RAG context injection" do
    context "when venue_chunks are passed" do
      subject(:extractor) do
        described_class.new(account:, booking_request:, client: build_client,
          venue_chunks: [ "The Rooftop holds 150 guests." ])
      end

      it "includes chunk content in the prompt" do
        extractor.call(subject: "Party inquiry", body_text: "40 guests")
        expect(AiRun.last.prompt).to include("The Rooftop holds 150 guests.")
      end

      it "stores rag_chunk_count on AiRun" do
        extractor.call(subject: "Party inquiry", body_text: "40 guests")
        expect(AiRun.last.rag_chunk_count).to eq(1)
      end

      it "prefixes the prompt with Venue Context" do
        extractor.call(subject: "Party inquiry", body_text: "40 guests")
        expect(AiRun.last.prompt).to include("Venue Context:")
      end
    end

    context "when no venue_chunks are passed" do
      subject(:extractor) do
        described_class.new(account:, booking_request:, client: build_client)
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
