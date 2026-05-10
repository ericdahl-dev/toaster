# frozen_string_literal: true

module BookingRequests
  class Decisioner
    CONFIDENCE_THRESHOLD = 0.8

    def self.call(validated_result)
      new.call(validated_result)
    end

    def call(validated_result)
      return "reviewing" if missing_fields?(validated_result)
      return "reviewing" if low_confidence?(validated_result)
      return "reviewing" if not_a_fit?(validated_result)

      "pending"
    end

    private

    def missing_fields?(result)
      result[:missing_fields]&.any?
    end

    def low_confidence?(result)
      confidence = result[:confidence]
      confidence.nil? || confidence < CONFIDENCE_THRESHOLD
    end

    def not_a_fit?(result)
      %w[not_a_fit in_progress].include?(result[:fit_status])
    end
  end
end
