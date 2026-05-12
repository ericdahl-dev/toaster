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
      UnstructuredClient.extract(doc.file_path)
    rescue Net::ReadTimeout, Net::OpenTimeout, Errno::ETIMEDOUT => e
      raise ApiTimeoutError, e.message
    end

    chunks = TextChunker.call(text)

    doc.venue_chunks.delete_all

    chunks.each do |chunk_text|
      embedding = VenueEmbedder.embed(chunk_text)
      raise "OpenAI returned no embedding (check OPENAI_API_KEY and model access)" if embedding.nil?

      doc.venue_chunks.create!(content: chunk_text, embedding: embedding)
    end

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
