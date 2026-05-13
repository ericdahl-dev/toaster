# frozen_string_literal: true

require "rails_helper"

RSpec.describe AiCostCalculator do
  describe ".openai_cost_cents" do
    it "calculates cost for gpt-4o-mini" do
      cost = described_class.openai_cost_cents(model: "gpt-4o-mini", input_tokens: 1_000_000, output_tokens: 1_000_000)
      expect(cost).to eq(75) # (0.15 + 0.60) / 2 * 100 = 37.5 each, 75 total
    end

    it "calculates cost for text-embedding-3-large (input only)" do
      cost = described_class.openai_cost_cents(model: "text-embedding-3-large", input_tokens: 1_000_000, output_tokens: 0)
      expect(cost).to eq(13) # 0.13 / 100 * 100 = 13 cents
    end

    it "returns 0 for unknown model" do
      cost = described_class.openai_cost_cents(model: "unknown-model", input_tokens: 1_000_000, output_tokens: 1_000_000)
      expect(cost).to eq(0)
    end

    it "treats nil token counts as zero" do
      cost = described_class.openai_cost_cents(model: "gpt-4o-mini", input_tokens: nil, output_tokens: nil)
      expect(cost).to eq(0)
    end
  end

  describe ".unstructured_cost_cents" do
    it "calculates cost per page at $0.001/page" do
      cost = described_class.unstructured_cost_cents(page_count: 1000)
      expect(cost).to eq(100) # $1.00
    end

    it "returns 0 for nil page_count" do
      cost = described_class.unstructured_cost_cents(page_count: nil)
      expect(cost).to eq(0)
    end

    it "returns 0 for zero pages" do
      cost = described_class.unstructured_cost_cents(page_count: 0)
      expect(cost).to eq(0)
    end
  end
end
