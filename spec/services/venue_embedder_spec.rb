# frozen_string_literal: true

require "rails_helper"

RSpec.describe VenueEmbedder do
  let(:fake_embedding) { Array.new(3072, 0.1) }
  let(:openai_client) { instance_double(OpenAI::Client) }

  before do
    stub_const("ENV", ENV.to_h.merge("OPENAI_API_KEY" => "test-key"))
    allow(OpenAI::Client).to receive(:new).with(access_token: "test-key").and_return(openai_client)
    allow(openai_client).to receive(:embeddings)
      .with(parameters: { model: "text-embedding-3-large", input: "hello world" })
      .and_return({ "data" => [ { "embedding" => fake_embedding } ] })
  end

  describe ".embed" do
    it "returns a 3072-dimensional embedding vector" do
      result = described_class.embed("hello world")
      expect(result).to eq(fake_embedding)
    end

    it "uses the text-embedding-3-large model" do
      described_class.embed("hello world")
      expect(openai_client).to have_received(:embeddings)
        .with(parameters: { model: "text-embedding-3-large", input: "hello world" })
    end

    it "returns nil when OPENAI_API_KEY is absent" do
      stub_const("ENV", ENV.to_h.except("OPENAI_API_KEY"))
      expect(described_class.embed("hello")).to be_nil
    end

    it "returns nil when OpenAI returns no embedding data" do
      allow(openai_client).to receive(:embeddings).and_return({ "data" => [] })
      expect(described_class.embed("hello world")).to be_nil
    end
  end
end
