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
      .and_return({
        "data" => [ { "embedding" => fake_embedding } ],
        "usage" => { "total_tokens" => 7 }
      })
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
      allow(openai_client).to receive(:embeddings).and_return({ "data" => [], "usage" => { "total_tokens" => 0 } })
      expect(described_class.embed("hello world")).to be_nil
    end

    context "when account is provided" do
      let(:account) { create(:account) }

      it "creates an AiRun with token usage" do
        expect {
          described_class.embed("hello world", account: account)
        }.to change(AiRun, :count).by(1)

        run = AiRun.last
        expect(run.run_type).to eq("embedding")
        expect(run.llm_model).to eq("text-embedding-3-large")
        expect(run.input_tokens).to eq(7)
      end
    end
  end

  describe ".embed_batch" do
    let(:texts) { %w[hello world] }
    let(:batch_response) do
      {
        "data" => [
          { "index" => 0, "embedding" => fake_embedding },
          { "index" => 1, "embedding" => fake_embedding.map { |v| v * 2 } }
        ],
        "usage" => { "total_tokens" => 14 }
      }
    end

    before do
      allow(openai_client).to receive(:embeddings)
        .with(parameters: { model: "text-embedding-3-large", input: texts })
        .and_return(batch_response)
    end

    it "returns embeddings in index order" do
      result = described_class.embed_batch(texts)
      expect(result.size).to eq(2)
      expect(result.first).to eq(fake_embedding)
    end

    it "returns nil array when OPENAI_API_KEY is absent" do
      stub_const("ENV", ENV.to_h.except("OPENAI_API_KEY"))
      expect(described_class.embed_batch(texts)).to eq([nil, nil])
    end

    context "when account is provided" do
      let(:account) { create(:account) }

      it "creates an AiRun for the batch" do
        expect {
          described_class.embed_batch(texts, account: account)
        }.to change(AiRun, :count).by(1)

        run = AiRun.last
        expect(run.run_type).to eq("embedding")
        expect(run.input_tokens).to eq(14)
      end
    end
  end
end
