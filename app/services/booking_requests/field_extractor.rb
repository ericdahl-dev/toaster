module BookingRequests
  class FieldExtractor
    MONTH_NAME_DATE = /\b(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\s+\d{1,2}(?:,\s*\d{4})?\b/i
    HEADCOUNT = /\b(\d{1,4})\s+(?:guests?|people|attendees?)\b/i
    BUDGET = /\$\s?(\d[\d,]*(?:\.\d{2})?)/

    def self.call(subject:, body_text:)
      new(subject: subject, body_text: body_text).call
    end

    def initialize(subject:, body_text:)
      @source_text = [ subject, body_text ].compact.join("\n")
    end

    def call
      event_dates = extract_event_dates
      headcounts = extract_headcounts
      budgets = extract_budgets

      review_reasons = []

      event_date = single_value(event_dates) { review_reasons << "ambiguous_event_date" }
      headcount = single_value(headcounts) { review_reasons << "ambiguous_headcount" }
      budget_cents = single_value(budgets) { review_reasons << "ambiguous_budget_cents" }

      missing_fields = []
      missing_fields << "event_date" if event_date.nil?
      missing_fields << "headcount" if headcount.nil?
      missing_fields << "budget_cents" if budget_cents.nil?

      snapshot = {
        "event_date" => event_date&.iso8601,
        "headcount" => headcount,
        "budget_cents" => budget_cents
      }

      {
        event_date: event_date,
        headcount: headcount,
        budget_cents: budget_cents,
        missing_fields: missing_fields,
        review_reasons: review_reasons,
        snapshot: snapshot,
        status: (missing_fields.any? || review_reasons.any?) ? "reviewing" : "pending"
      }
    end

    private

    attr_reader :source_text

    def extract_event_dates
      source_text.scan(MONTH_NAME_DATE).filter_map do |match|
        next unless match.match?(/\d{4}/)
        Date.parse(match)
      rescue Date::Error
        nil
      end.uniq.sort
    end

    def extract_headcounts
      source_text.scan(HEADCOUNT).flatten.map(&:to_i).uniq.sort
    end

    def extract_budgets
      source_text.scan(BUDGET).flatten.map do |raw|
        (BigDecimal(raw.delete(",")) * 100).to_i
      end.uniq.sort
    end

    def single_value(values)
      return values.first if values.one?
      yield if values.many?
      nil
    end
  end
end
