# frozen_string_literal: true

require "rails_helper"

RSpec.describe BookingRequests::ValidateExtraction do
  let(:account) { create(:account) }
  let(:venue) { create(:venue, account:) }
  let(:booking_request) { create(:booking_request, account:, venue:) }

  let(:base_result) do
    {
      event_date: Date.new(2026, 6, 14),
      headcount: 40,
      budget: 500.0,
      start_time: "7:00 PM",
      celebration_type: "birthday",
      confidence: 0.95,
      notes: nil
    }
  end

  subject(:validator) { described_class.new(booking_request:) }

  describe "#call" do
    context "when booking_request has no venue" do
      let(:booking_request) { create(:booking_request, account:, venue: nil) }

      it "returns fit_status nil" do
        result = validator.call(base_result)
        expect(result[:fit_status]).to be_nil
      end
    end

    context "when venue has no spaces" do
      it "returns fit_status nil" do
        result = validator.call(base_result)
        expect(result[:fit_status]).to be_nil
      end
    end

    context "when headcount is nil" do
      it "returns fit_status in_progress" do
        create(:venue_space, venue:, min_guests: 20, capacity_reception: 100, pricing_floor_cents: 20000)
        result = validator.call(base_result.merge(headcount: nil))
        expect(result[:fit_status]).to eq("in_progress")
      end
    end

    context "when headcount is within a space's range" do
      before { create(:venue_space, venue:, min_guests: 20, capacity_reception: 100, pricing_floor_cents: 20000) }

      it "returns fit_status qualified" do
        result = validator.call(base_result)
        expect(result[:fit_status]).to eq("qualified")
      end
    end

    context "when headcount exceeds all spaces" do
      before { create(:venue_space, venue:, min_guests: nil, capacity_reception: 30, pricing_floor_cents: nil) }

      it "returns fit_status not_a_fit" do
        result = validator.call(base_result.merge(headcount: 50))
        expect(result[:fit_status]).to eq("not_a_fit")
      end
    end

    context "when budget is below all spaces pricing floor" do
      before { create(:venue_space, venue:, min_guests: nil, capacity_reception: 100, pricing_floor_cents: 200000) }

      it "returns fit_status not_a_fit" do
        result = validator.call(base_result.merge(budget: 500.0))
        expect(result[:fit_status]).to eq("not_a_fit")
      end
    end

    it "computes missing_fields for nil required values" do
      result = validator.call(base_result.merge(event_date: nil, headcount: nil))
      expect(result[:missing_fields]).to include("event_date", "headcount")
      expect(result[:missing_fields]).not_to include("budget", "start_time", "celebration_type")
    end

    it "includes staff_summary string" do
      result = validator.call(base_result)
      expect(result[:staff_summary]).to be_a(String)
      expect(result[:staff_summary]).not_to be_empty
    end

    it "passes through extractor fields" do
      result = validator.call(base_result)
      expect(result[:event_date]).to eq(Date.new(2026, 6, 14))
      expect(result[:headcount]).to eq(40)
      expect(result[:budget]).to eq(500.0)
      expect(result[:confidence]).to eq(0.95)
    end
  end
end
