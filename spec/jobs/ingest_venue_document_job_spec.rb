# frozen_string_literal: true

require "rails_helper"

RSpec.describe IngestVenueDocumentJob, type: :job do
  let(:fake_embedding) { Array.new(3072, 0.1) }
  let(:fixture_text) { "This is a sample venue document with some content about the space." }

  let(:openai_response) do
    {"data" => [{"embedding" => fake_embedding}]}
  end

  let(:openai_client) { instance_double(OpenAI::Client) }

  before do
    stub_const("ENV", ENV.to_h.merge("OPENAI_API_KEY" => "test-key"))
    allow(OpenAI::Client).to receive(:new).and_return(openai_client)
    allow(openai_client).to receive(:embeddings).and_return(openai_response)
    allow(UnstructuredClient).to receive(:extract).and_return(fixture_text)
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

    it "requests embeddings from OpenAI for each chunk" do
      described_class.perform_now(doc.id)

      expect(openai_client).to have_received(:embeddings).at_least(:once)
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

    context "when OpenAI raises" do
      before do
        allow(openai_client).to receive(:embeddings).and_raise(RuntimeError, "OpenAI error")
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
  end
end
