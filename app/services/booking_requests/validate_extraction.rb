# frozen_string_literal: true

module BookingRequests
  class ValidateExtraction
    TRACKED_FIELDS = %i[event_date headcount budget].freeze

    def initialize(booking_request:)
      @booking_request = booking_request
    end

    def call(extractor_result)
      missing = compute_missing_fields(extractor_result)
      fit = compute_fit_status(extractor_result, missing)
      summary = compute_staff_summary(extractor_result, fit, missing)

      extractor_result.merge(
        fit_status: fit,
        missing_fields: missing,
        staff_summary: summary
      )
    end

    private

    attr_reader :booking_request

    def spaces
      @spaces ||= booking_request.venue&.venue_spaces&.to_a || []
    end

    def compute_missing_fields(result)
      TRACKED_FIELDS.select { |f| result[f].nil? }.map(&:to_s)
    end

    def compute_fit_status(result, missing)
      return nil if booking_request.venue.nil?
      return nil if spaces.empty?
      return "in_progress" if missing.include?("headcount")

      headcount = result[:headcount]
      budget_dollars = result[:budget]

      fits_any = spaces.any? do |space|
        headcount_ok?(space, headcount) && budget_ok?(space, budget_dollars)
      end

      fits_any ? "qualified" : "not_a_fit"
    end

    def headcount_ok?(space, headcount)
      max = space.capacity_reception || space.capacity_seated
      min = space.min_guests

      above_min = min.nil? || headcount >= min
      below_max = max.nil? || headcount <= max

      above_min && below_max
    end

    def budget_ok?(space, budget_dollars)
      floor_cents = space.pricing_floor_cents
      return true if floor_cents.nil? || budget_dollars.nil?

      (budget_dollars * 100) >= floor_cents
    end

    def compute_staff_summary(result, fit, missing)
      parts = []
      parts << "#{result[:headcount]} guests" if result[:headcount]
      parts << "on #{result[:event_date]}" if result[:event_date]
      parts << "budget $#{result[:budget]}" if result[:budget]
      parts << "(#{result[:celebration_type]})" if result[:celebration_type]
      parts << "[fit: #{fit}]" if fit
      parts << "[missing: #{missing.join(", ")}]" if missing.any?
      parts.join(" ")
    end
  end
end
