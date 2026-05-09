# frozen_string_literal: true

class IngestVenueDocumentJob < ApplicationJob
  queue_as :default

  def perform(venue_document_id)
    doc = VenueDocument.find(venue_document_id)
    doc.processing!

    text = UnstructuredClient.extract(doc.file_path)
    chunks = TextChunker.call(text)

    client = OpenAI::Client.new
    doc.venue_chunks.delete_all

    chunks.each do |chunk_text|
      embedding = client.embeddings(
        parameters: {model: "text-embedding-3-large", input: chunk_text}
      ).dig("data", 0, "embedding")

      doc.venue_chunks.create!(content: chunk_text, embedding: embedding)
    end

    doc.update!(status: :ready, chunk_count: chunks.size)
  rescue => e
    doc&.update!(status: :failed, error_message: e.message)
    raise
  end
end
