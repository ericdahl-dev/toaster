# frozen_string_literal: true

class IngestVenueDocumentJob < ApplicationJob
  queue_as :default

  class ConfigurationError < StandardError; end

  def perform(venue_document_id)
    doc = VenueDocument.find(venue_document_id)
    doc.processing!

    raise ConfigurationError, "OPENAI_API_KEY is not configured" if ENV["OPENAI_API_KEY"].blank?

    text = UnstructuredClient.extract(doc.file_path)
    chunks = TextChunker.call(text)

    doc.venue_chunks.delete_all

    chunks.each do |chunk_text|
      embedding = VenueEmbedder.embed(chunk_text)
      raise "OpenAI returned no embedding (check OPENAI_API_KEY and model access)" if embedding.nil?

      doc.venue_chunks.create!(content: chunk_text, embedding: embedding)
    end

    doc.update!(status: :ready, chunk_count: chunks.size)
  rescue => e
    doc&.update!(status: :failed, error_message: e.message)
    raise
  end
end
