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

  describe "recommended_venue_space_id" do
    context "when no venue assigned" do
      let(:booking_request) { create(:booking_request, account:, venue: nil) }

      it "leaves recommended_venue_space_id nil" do
        result = validator.call(base_result)
        expect(result[:recommended_venue_space_id]).to be_nil
      end
    end

    context "when venue has no spaces" do
      it "leaves recommended_venue_space_id nil" do
        result = validator.call(base_result)
        expect(result[:recommended_venue_space_id]).to be_nil
      end
    end

    context "single qualifying space" do
      let!(:space) { create(:venue_space, venue:, min_guests: 20, capacity_reception: 100, pricing_floor_cents: nil) }

      it "populates recommended_venue_space_id" do
        result = validator.call(base_result)
        expect(result[:recommended_venue_space_id]).to eq(space.id)
      end
    end

    context "private_space_preference tiebreak" do
      let!(:public_space) { create(:venue_space, venue:, min_guests: nil, max_guests: 100, private: false, pricing_floor_cents: nil) }
      let!(:private_space) { create(:venue_space, venue:, min_guests: nil, max_guests: 100, private: true, pricing_floor_cents: nil) }

      it "prefers private space when preference is private" do
        result = validator.call(base_result.merge(private_space_preference: "private"))
        expect(result[:recommended_venue_space_id]).to eq(private_space.id)
      end

      it "prefers non-private space when preference is semi_private" do
        result = validator.call(base_result.merge(private_space_preference: "semi_private"))
        expect(result[:recommended_venue_space_id]).to eq(public_space.id)
      end
    end

    context "duration tiebreak" do
      let!(:no_duration_space) { create(:venue_space, venue:, min_guests: nil, max_guests: 100, duration_options: [], pricing_floor_cents: 1000) }
      let!(:matching_duration_space) { create(:venue_space, venue:, min_guests: nil, max_guests: 100, duration_options: [ "2_hours", "all_night" ], pricing_floor_cents: 2000) }

      it "prefers space with matching duration option" do
        result = validator.call(base_result.merge(duration: "2_hours"))
        expect(result[:recommended_venue_space_id]).to eq(matching_duration_space.id)
      end
    end

    context "feature_preferences tiebreak" do
      let!(:no_features_space) { create(:venue_space, venue:, min_guests: nil, max_guests: 100, features: [], pricing_floor_cents: nil) }
      let!(:matching_features_space) { create(:venue_space, venue:, min_guests: nil, max_guests: 100, features: [ "private_bar", "stage" ], pricing_floor_cents: nil) }

      it "prefers space with more feature overlap" do
        result = validator.call(base_result.merge(feature_preferences: [ "private_bar" ]))
        expect(result[:recommended_venue_space_id]).to eq(matching_features_space.id)
      end
    end

    context "pricing tiebreak on equal score" do
      let!(:expensive_space) { create(:venue_space, venue:, min_guests: nil, max_guests: 100, pricing_floor_cents: 50000) }
      let!(:cheap_space) { create(:venue_space, venue:, min_guests: nil, max_guests: 100, pricing_floor_cents: 10000) }

      it "picks space with lower pricing_floor_cents" do
        result = validator.call(base_result)
        expect(result[:recommended_venue_space_id]).to eq(cheap_space.id)
      end
    end

    context "no fitting space (exceeds all capacities)" do
      before { create(:venue_space, venue:, min_guests: nil, max_guests: 10, pricing_floor_cents: nil) }

      it "sets fit_status not_a_fit and leaves recommended_venue_space_id nil" do
        result = validator.call(base_result.merge(headcount: 50))
        expect(result[:fit_status]).to eq("not_a_fit")
        expect(result[:recommended_venue_space_id]).to be_nil
      end
    end
  end
end
