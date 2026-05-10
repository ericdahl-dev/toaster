# frozen_string_literal: true

require "rails_helper"

RSpec.describe BookingRequests::Extract do
  let(:account) { create(:account) }
  let(:inbox_message) do
    create(:inbox_message,
      account: account,
      from_email: "guest@example.com",
      from_name: "Guest",
      subject: "Party inquiry",
      body_text: "We want to book for 40 guests.")
  end

  before do
    stub_const("ENV", ENV.to_h.merge("OPENAI_API_KEY" => "test-key"))
    allow_any_instance_of(BookingRequests::Classifier).to receive(:call_openai)
      .and_return({ "booking_request" => true })
    allow_any_instance_of(BookingRequests::LlmExtractor).to receive(:call_openai)
      .and_return({
        "event_date" => nil, "headcount" => 40, "budget" => nil,
        "start_time" => nil, "celebration_type" => nil,
        "confidence" => 0.9, "notes" => nil
      })
  end

  describe ".call" do
    it "returns a Result with a saved BookingRequest" do
      result = described_class.call(inbox_message: inbox_message)
      expect(result.booking_request).to be_persisted
    end

    it "does not call LLM inside an open transaction" do
      baseline_transactions = ActiveRecord::Base.connection.open_transactions
      llm_called_in_extra_transaction = false

      allow_any_instance_of(BookingRequests::Classifier).to receive(:call_openai) do
        llm_called_in_extra_transaction = ActiveRecord::Base.connection.open_transactions > baseline_transactions
        { "booking_request" => true }
      end

      described_class.call(inbox_message: inbox_message)

      expect(llm_called_in_extra_transaction).to be false
    end

    it "does not re-call LLM on RecordNotUnique retry" do
      call_count = 0
      allow_any_instance_of(BookingRequests::Classifier).to receive(:call_openai) do
        call_count += 1
        { "booking_request" => true }
      end

      # Simulate RecordNotUnique on first attempt then succeed
      attempts = 0
      original_save = BookingRequest.instance_method(:save!)
      allow_any_instance_of(BookingRequest).to receive(:save!) do |instance|
        attempts += 1
        raise ActiveRecord::RecordNotUnique if attempts == 1
        original_save.bind_call(instance)
      end

      described_class.call(inbox_message: inbox_message)

      expect(call_count).to eq(1)
    end

    context "when classifier returns false" do
      before do
        allow_any_instance_of(BookingRequests::Classifier).to receive(:call_openai)
          .and_return({ "booking_request" => false })
      end

      it "returns nil without creating a BookingRequest" do
        expect(described_class.call(inbox_message: inbox_message)).to be_nil
        expect(BookingRequest.count).to eq(0)
      end
    end

    context "when venue is provided" do
      let(:venue) { create(:venue, account:) }

      before do
        allow(BookingRequests::VenueRagRetriever).to receive(:call).and_return([ "The Rooftop holds 150 guests." ])
      end

      it "calls VenueRagRetriever with the venue and query" do
        described_class.call(inbox_message: inbox_message, venue: venue)
        expect(BookingRequests::VenueRagRetriever).to have_received(:call).with(
          venue: venue,
          query: a_string_including("Party inquiry")
        )
      end

      it "passes retrieved chunks to LlmExtractor via rag_chunk_count on AiRun" do
        described_class.call(inbox_message: inbox_message, venue: venue)
        extraction_run = AiRun.where(run_type: "extraction").last
        expect(extraction_run.rag_chunk_count).to eq(1)
      end
    end

    context "when no venue is provided" do
      it "does not call VenueRagRetriever" do
        allow(BookingRequests::VenueRagRetriever).to receive(:call)
        described_class.call(inbox_message: inbox_message)
        expect(BookingRequests::VenueRagRetriever).not_to have_received(:call)
      end
    end
  end
end
