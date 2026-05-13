# frozen_string_literal: true

# Per-token and per-page pricing for external AI/ML APIs.
# All rates are in USD per unit. Update when pricing changes.
#
# OpenAI pricing: https://openai.com/pricing
# Unstructured pricing: https://unstructured.io/pricing
module AiCostCalculator
  # USD per 1M tokens
  OPENAI_RATES = {
    "gpt-4o-mini" => {input: 0.15, output: 0.60},
    "text-embedding-3-large" => {input: 0.13, output: 0.0}
  }.freeze

  # USD per page
  UNSTRUCTURED_RATE_PER_PAGE = 0.001

  # Returns estimated cost in cents (integer) for an OpenAI call.
  def self.openai_cost_cents(model:, input_tokens:, output_tokens:)
    rates = OPENAI_RATES[model]
    return 0 unless rates

    input_tokens ||= 0
    output_tokens ||= 0

    usd = (input_tokens * rates[:input] + output_tokens * rates[:output]) / 1_000_000.0
    (usd * 100).round
  end

  # Returns estimated cost in cents (integer) for an Unstructured.io call.
  def self.unstructured_cost_cents(page_count:)
    page_count ||= 0
    usd = page_count * UNSTRUCTURED_RATE_PER_PAGE
    (usd * 100).round
  end
end
