class AiRun < ApplicationRecord
  RUN_TYPES = %w[classifier extraction draft_writer embedding unstructured].freeze

  belongs_to :account
  belongs_to :booking_request, optional: true

  validates :llm_model, presence: true
  validates :prompt, presence: true
  validates :run_type, presence: true, inclusion: { in: RUN_TYPES }

  validate :booking_request_belongs_to_account

  after_create_commit :fire_posthog_event

  private

  def booking_request_belongs_to_account
    return unless booking_request && account
    if booking_request.account_id != account_id
      errors.add(:booking_request, "must belong to the same account")
    end
  end

  def fire_posthog_event
    Telemetry.capture(
      distinct_id: "account_#{account_id}",
      event: "ai_cost_incurred",
      properties: {
        run_type: run_type,
        llm_model: llm_model,
        input_tokens: input_tokens,
        output_tokens: output_tokens,
        page_count: page_count,
        estimated_cost_cents: estimated_cost_cents,
        latency_ms: latency_ms,
        booking_request_id: booking_request_id
      }.compact
    )
  rescue => e
    Rails.logger.warn("AiRun#fire_posthog_event failed: #{e.message}")
  end
end
