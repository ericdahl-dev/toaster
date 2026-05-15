# frozen_string_literal: true

# Wraps the OpenAI embeddings API for the venue RAG pipeline.
# Single source of truth for model name, API key, and client creation.
class VenueEmbedder
  EMBEDDING_MODEL = "text-embedding-3-large"

  def self.embed(text, account: nil)
    api_key = ENV["OPENAI_API_KEY"].presence
    return nil if api_key.nil?

    client = OpenAI::Client.new(access_token: api_key)
    response = client.embeddings(parameters: {model: EMBEDDING_MODEL, input: text})

    if account
      input_tokens = response.dig("usage", "total_tokens")
      AiRun.create!(
        account: account,
        run_type: "embedding",
        llm_model: EMBEDDING_MODEL,
        prompt_version: "1",
        prompt: text.truncate(500),
        response: "",
        latency_ms: 0,
        input_tokens: input_tokens,
        output_tokens: 0,
        estimated_cost_cents: AiCostCalculator.openai_cost_cents(
          model: EMBEDDING_MODEL,
          input_tokens: input_tokens || 0,
          output_tokens: 0
        )
      )
    end

    response.dig("data", 0, "embedding")
  end

  def self.embed_batch(texts, account: nil)
    api_key = ENV["OPENAI_API_KEY"].presence
    return texts.map { nil } if api_key.nil?

    client = OpenAI::Client.new(access_token: api_key)
    response = client.embeddings(parameters: {model: EMBEDDING_MODEL, input: texts})

    if account
      input_tokens = response.dig("usage", "total_tokens")
      AiRun.create!(
        account: account,
        run_type: "embedding",
        llm_model: EMBEDDING_MODEL,
        prompt_version: "1",
        prompt: "batch:#{texts.size} chunks",
        response: "",
        latency_ms: 0,
        input_tokens: input_tokens,
        output_tokens: 0,
        estimated_cost_cents: AiCostCalculator.openai_cost_cents(
          model: EMBEDDING_MODEL,
          input_tokens: input_tokens || 0,
          output_tokens: 0
        )
      )
    end

    data = response.fetch("data")
    data.sort_by { |d| d["index"] }.map { |d| d["embedding"] }
  end
end
