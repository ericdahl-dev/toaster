# frozen_string_literal: true

# Best-effort Turbo timeline pushes; failures must not break ingestion or jobs.
class TurboTimelineBroadcast
  def self.deliver(booking_request:, operation:, &block)
    new(booking_request: booking_request, operation: operation).deliver(&block)
  end

  def initialize(booking_request:, operation:)
    @booking_request = booking_request
    @operation = operation
  end

  def deliver
    yield
  rescue StandardError => e
    Rails.logger.error(
      "[TurboTimelineBroadcast] #{operation} failed " \
      "booking_request_id=#{booking_request.id}: #{e.class}: #{e.message}"
    )
  end

  private

  attr_reader :booking_request, :operation
end
