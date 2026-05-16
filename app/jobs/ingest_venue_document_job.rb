# frozen_string_literal: true

class IngestVenueDocumentJob < ApplicationJob
  queue_as :default

  class ConfigurationError < StandardError; end
  class ApiTimeoutError < StandardError; end

  retry_on ApiTimeoutError, wait: :polynomially_longer, attempts: 5 do |job, error|
    venue_document_id = job.arguments.first
    job.discard_with_event_log(venue_document_id, error)
  end

  def perform(venue_document_id)
    doc = VenueDocument.find(venue_document_id)
    doc.processing!

    raise ConfigurationError, "OPENAI_API_KEY is not configured" if ENV["OPENAI_API_KEY"].blank?

    text = begin
      result = UnstructuredClient.extract(doc.file_path)
      page_count = result[:page_count]

      AiRun.create!(
        account: doc.venue.account,
        run_type: "unstructured",
        llm_model: "unstructured",
        prompt_version: "1",
        prompt: doc.source_filename,
        response: "",
        latency_ms: 0,
        page_count: page_count,
        estimated_cost_cents: AiCostCalculator.unstructured_cost_cents(page_count: page_count)
      )

      result[:text]
    rescue Net::ReadTimeout, Net::OpenTimeout, Errno::ETIMEDOUT => e
      raise ApiTimeoutError, e.message
    end

    chunks = TextChunker.call(text)

    doc.venue_chunks.delete_all

    embeddings = VenueEmbedder.embed_batch(chunks, account: doc.venue.account)
    raise "OpenAI returned no embeddings (check OPENAI_API_KEY and model access)" if embeddings.any?(&:nil?)

    records = chunks.zip(embeddings).map do |chunk_text, embedding|
      { content: chunk_text, embedding: embedding }
    end
    doc.venue_chunks.create!(records)

    doc.update!(status: :ready, chunk_count: chunks.size)
  rescue ApiTimeoutError => e
    doc&.update!(status: :failed, error_message: e.message)
    raise
  rescue => e
    doc&.update!(status: :failed, error_message: e.message)
    raise
  end

  def discard_with_event_log(venue_document_id, error)
    doc = VenueDocument.find_by(id: venue_document_id)
    account = doc&.venue&.account
    return unless account

    EventLog.create!(
      account: account,
      event_type: "ingest_venue_document.timeout_exhausted",
      payload: {
        venue_document_id: venue_document_id,
        error: error.message
      }
    )
  end
end
