# frozen_string_literal: true

module Telemetry
  def self.configured?
    ENV["POSTHOG_PROJECT_TOKEN"].present?
  end

  def self.capture(distinct_id:, event:, properties: {})
    return unless configured?

    PostHog.capture(distinct_id: distinct_id, event: event, properties: properties)
  rescue => e
    Rails.logger.warn("Telemetry#capture failed: #{e.message}")
  end

  def self.capture_exception(exception, distinct_id)
    return unless configured?

    PostHog.capture_exception(exception, distinct_id)
  rescue => e
    Rails.logger.warn("Telemetry#capture_exception failed: #{e.message}")
  end

  def self.identify(distinct_id:, properties: {})
    return unless configured?

    PostHog.identify(distinct_id: distinct_id, properties: properties)
  rescue => e
    Rails.logger.warn("Telemetry#identify failed: #{e.message}")
  end
end
