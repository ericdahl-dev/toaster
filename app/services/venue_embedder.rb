# frozen_string_literal: true

# Wraps the OpenAI embeddings API for the venue RAG pipeline.
# Single source of truth for model name, API key, and client creation.
class VenueEmbedder
  EMBEDDING_MODEL = "text-embedding-3-large"

  def self.embed(text)
    api_key = ENV["OPENAI_API_KEY"].presence
    return nil if api_key.nil?

    client = OpenAI::Client.new(access_token: api_key)
    response = client.embeddings(parameters: { model: EMBEDDING_MODEL, input: text })
    response.dig("data", 0, "embedding")
  end
end
