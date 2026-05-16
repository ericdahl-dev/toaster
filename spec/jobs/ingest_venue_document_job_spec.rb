# frozen_string_literal: true

require "rails_helper"

RSpec.describe IngestVenueDocumentJob, type: :job do
  let(:fake_embedding) { Array.new(3072, 0.1) }
  let(:fixture_text) { "This is a sample venue document with some content about the space." }

  before do
    stub_const("ENV", ENV.to_h.merge("OPENAI_API_KEY" => "test-key"))
    allow(VenueEmbedder).to receive(:embed).with(anything, account: anything).and_return(fake_embedding)
    allow(VenueEmbedder).to receive(:embed_batch).with(anything, account: anything).and_wrap_original do |_m, texts, account:|
      texts.map { fake_embedding }
    end
    allow(UnstructuredClient).to receive(:extract).and_return({ text: fixture_text, page_count: 3 })
  end

  describe "#perform" do
    let(:doc) { create(:venue_document, status: :pending) }

    it "transitions doc from pending to processing to ready" do
      described_class.perform_now(doc.id)

      expect(doc.reload.status).to eq("ready")
    end

    it "creates venue chunks from the extracted text" do
      described_class.perform_now(doc.id)

      expect(doc.reload.venue_chunks.count).to be >= 1
    end

    it "stores the correct chunk count on the document" do
      described_class.perform_now(doc.id)

      doc.reload
      expect(doc.chunk_count).to eq(doc.venue_chunks.count)
    end

    it "stores chunk content" do
      described_class.perform_now(doc.id)

      contents = doc.reload.venue_chunks.pluck(:content)
      expect(contents).not_to be_empty
      expect(contents.first).to include("venue document")
    end

    it "calls UnstructuredClient with the file path" do
      described_class.perform_now(doc.id)

      expect(UnstructuredClient).to have_received(:extract).with(doc.file_path)
    end

    it "requests embeddings via a single batch call" do
      described_class.perform_now(doc.id)

      expect(VenueEmbedder).to have_received(:embed_batch).once
      expect(VenueEmbedder).not_to have_received(:embed)
    end

    it "calls embed_batch exactly once regardless of chunk count" do
      long_text = "paragraph content. " * 200
      allow(UnstructuredClient).to receive(:extract).and_return({ text: long_text, page_count: 1 })

      described_class.perform_now(doc.id)

      expect(VenueEmbedder).to have_received(:embed_batch).once
    end

    context "when UnstructuredClient raises" do
      before do
        allow(UnstructuredClient).to receive(:extract).and_raise(RuntimeError, "API timeout")
      end

      it "transitions the doc to failed" do
        expect {
          described_class.perform_now(doc.id)
        }.to raise_error(RuntimeError)

        expect(doc.reload.status).to eq("failed")
      end

      it "records the error message" do
        expect {
          described_class.perform_now(doc.id)
        }.to raise_error(RuntimeError)

        expect(doc.reload.error_message).to eq("API timeout")
      end
    end

    context "when VenueEmbedder.embed_batch raises" do
      before do
        allow(VenueEmbedder).to receive(:embed_batch).and_raise(RuntimeError, "OpenAI error")
      end

      it "transitions the doc to failed and re-raises" do
        expect {
          described_class.perform_now(doc.id)
        }.to raise_error(RuntimeError)

        expect(doc.reload.status).to eq("failed")
      end
    end

    context "when the document does not exist" do
      it "raises ActiveRecord::RecordNotFound" do
        expect {
          described_class.perform_now(0)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when OPENAI_API_KEY is not set" do
      before { stub_const("ENV", ENV.to_h.except("OPENAI_API_KEY")) }

      it "transitions doc to failed with a clear message" do
        expect {
          described_class.perform_now(doc.id)
        }.to raise_error(IngestVenueDocumentJob::ConfigurationError, /OPENAI_API_KEY/)

        expect(doc.reload.status).to eq("failed")
        expect(doc.reload.error_message).to include("OPENAI_API_KEY")
      end
    end

    context "when UNSTRUCTURED_API_KEY is not set" do
      before do
        allow(UnstructuredClient).to receive(:extract).and_call_original
        stub_const("ENV", ENV.to_h.except("UNSTRUCTURED_API_KEY"))
      end

      it "transitions doc to failed with a clear message" do
        expect {
          described_class.perform_now(doc.id)
        }.to raise_error(UnstructuredClient::ConfigurationError, /UNSTRUCTURED_API_KEY/)

        expect(doc.reload.status).to eq("failed")
        expect(doc.reload.error_message).to include("UNSTRUCTURED_API_KEY")
      end
    end

    context "when UnstructuredClient raises ApiTimeoutError" do
      before do
        allow(UnstructuredClient).to receive(:extract).and_raise(IngestVenueDocumentJob::ApiTimeoutError, "API timeout")
      end

      it "marks doc as failed" do
        described_class.perform_now(doc.id)

        expect(doc.reload.status).to eq("failed")
      end

      it "records error message on doc" do
        described_class.perform_now(doc.id)

        expect(doc.reload.error_message).to eq("API timeout")
      end
    end

    context "when retries are exhausted after ApiTimeoutError" do
      let(:account) { doc.venue.account }

      it "records failure in EventLog" do
        job = described_class.new
        job.arguments = [ doc.id ]
        error = IngestVenueDocumentJob::ApiTimeoutError.new("API timeout")

        job.discard_with_event_log(doc.id, error)

        log = EventLog.where(account: account).last
        expect(log).not_to be_nil
        expect(log.event_type).to eq("ingest_venue_document.timeout_exhausted")
        expect(log.payload["error"]).to include("API timeout")
      end
    end
  end
end
