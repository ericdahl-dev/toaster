# frozen_string_literal: true

module BookingRequests
  class ValidateExtraction
    TRACKED_FIELDS = %i[event_date headcount budget].freeze
    CONFIDENCE_THRESHOLD = 0.8

    Result = Struct.new(:attrs, :status, keyword_init: true)

    def self.call(booking_request:, raw:)
      validated = new(booking_request:).enrich(raw)
      status = status_for(validated)
      Result.new(
        attrs: validated.slice(
          :event_date, :headcount, :budget, :start_time, :celebration_type,
          :fit_status, :staff_summary, :missing_fields, :recommended_venue_space_id
        ),
        status: status
      )
    end

    def self.status_for(validated_result)
      return "reviewing" if validated_result[:missing_fields]&.any?
      return "reviewing" if low_confidence?(validated_result)
      return "reviewing" if not_a_fit?(validated_result)

      "pending"
    end
    private_class_method :status_for

    def self.low_confidence?(result)
      confidence = result[:confidence]
      confidence.nil? || confidence < CONFIDENCE_THRESHOLD
    end
    private_class_method :low_confidence?

    def self.not_a_fit?(result)
      %w[not_a_fit in_progress].include?(result[:fit_status])
    end
    private_class_method :not_a_fit?

    def initialize(booking_request:)
      @booking_request = booking_request
    end

    def enrich(extractor_result)
      missing = compute_missing_fields(extractor_result)
      recommended_space = recommend_venue_space(extractor_result)
      fit = compute_fit_status(extractor_result, missing, recommended_space)
      summary = compute_staff_summary(extractor_result, fit, missing)

      extractor_result.merge(
        fit_status: fit,
        missing_fields: missing,
        staff_summary: summary,
        recommended_venue_space_id: recommended_space&.id
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

    def recommend_venue_space(result)
      return nil if booking_request.venue.nil?
      return nil if spaces.empty?

      headcount = result[:headcount]
      candidates = headcount ? spaces.select { |s| headcount_within_range?(s, headcount) } : spaces

      return nil if candidates.empty?

      scored = candidates.map { |s| [ s, score_space(s, result) ] }
      best_score = scored.map(&:last).max
      finalists = scored.select { |_, score| score == best_score }.map(&:first)

      finalists.min_by { |s| s.pricing_floor_cents || 0 }
    end

    def headcount_within_range?(space, headcount)
      min_ok = space.min_guests.nil? || headcount >= space.min_guests
      max_ok = space.max_guests.nil? || headcount <= space.max_guests
      cap = space.capacity_reception || space.capacity_seated
      cap_ok = cap.nil? || headcount <= cap
      min_ok && max_ok && cap_ok
    end

    def score_space(space, result)
      score = 0

      privacy_pref = result[:private_space_preference]
      if privacy_pref == "private" && space.private
        score += 1
      elsif privacy_pref == "semi_private" && !space.private
        score += 1
      end

      duration = result[:duration]
      score += 1 if duration && space.duration_options.include?(duration)

      feature_prefs = result[:feature_preferences] || []
      unless feature_prefs.empty?
        venue_features = booking_request.venue&.features || []
        all_features = (venue_features + (space.features || [])).uniq
        score += (feature_prefs & all_features).size
      end

      score
    end

    def compute_fit_status(result, missing, recommended_space)
      return nil if booking_request.venue.nil?
      return nil if spaces.empty?
      return "in_progress" if missing.include?("headcount")

      headcount = result[:headcount]
      budget_dollars = result[:budget]

      fits_any = spaces.any? do |space|
        headcount_ok?(space, headcount) && budget_ok?(space, budget_dollars)
      end

      return "not_a_fit" unless fits_any

      recommended_space ? "qualified" : "in_progress"
    end

    def headcount_ok?(space, headcount)
      max = space.capacity_reception || space.capacity_seated
      min = space.min_guests
      max_guests = space.max_guests

      above_min = min.nil? || headcount >= min
      below_cap = max.nil? || headcount <= max
      below_max_guests = max_guests.nil? || headcount <= max_guests

      above_min && below_cap && below_max_guests
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
