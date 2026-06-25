# frozen_string_literal: true

require "rails_helper"

RSpec.describe BookingRequests::ValidateExtraction do
  let(:account) { create(:account) }
  let(:venue) { create(:venue, account:) }
  let(:booking_request) { create(:booking_request, account:, venue:) }

  let(:base_raw) do
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

  describe ".call" do
    subject(:result) { described_class.call(booking_request:, raw: base_raw) }

    it "returns a Result with attrs and status" do
      expect(result).to be_a(described_class::Result)
      expect(result.attrs).to be_a(Hash)
      expect(result.status).to be_a(String)
    end

    context "status" do
      it "is pending when confidence is high, all fields present, and qualified" do
        create(:venue_space, venue:, min_guests: nil, capacity_reception: 100, pricing_floor_cents: nil)
        expect(result.status).to eq("pending")
      end

      it "is reviewing when confidence is below threshold" do
        expect(described_class.call(booking_request:, raw: base_raw.merge(confidence: 0.7)).status).to eq("reviewing")
      end

      it "is reviewing when fit_status is not_a_fit" do
        create(:venue_space, venue:, min_guests: nil, capacity_reception: 10, pricing_floor_cents: nil)
        expect(described_class.call(booking_request:, raw: base_raw.merge(headcount: 50)).status).to eq("reviewing")
      end

      it "is reviewing when missing fields are present" do
        expect(described_class.call(booking_request:, raw: base_raw.merge(event_date: nil)).status).to eq("reviewing")
      end

      it "is pending when fit_status is nil (no venue configured)" do
        booking_request_no_venue = create(:booking_request, account:, venue: nil)
        expect(described_class.call(booking_request: booking_request_no_venue, raw: base_raw).status).to eq("pending")
      end
    end

    context "attrs" do
      context "when booking_request has no venue" do
        let(:booking_request) { create(:booking_request, account:, venue: nil) }

        it "returns fit_status nil" do
          expect(result.attrs[:fit_status]).to be_nil
        end
      end

      context "when venue has no spaces" do
        it "returns fit_status nil" do
          expect(result.attrs[:fit_status]).to be_nil
        end
      end

      context "when headcount is nil" do
        it "returns fit_status in_progress" do
          create(:venue_space, venue:, min_guests: 20, capacity_reception: 100, pricing_floor_cents: 20000)
          result = described_class.call(booking_request:, raw: base_raw.merge(headcount: nil))
          expect(result.attrs[:fit_status]).to eq("in_progress")
        end
      end

      context "when headcount is within a space's range" do
        before { create(:venue_space, venue:, min_guests: 20, capacity_reception: 100, pricing_floor_cents: 20000) }

        it "returns fit_status qualified" do
          expect(result.attrs[:fit_status]).to eq("qualified")
        end
      end

      context "when headcount exceeds all spaces" do
        before { create(:venue_space, venue:, min_guests: nil, capacity_reception: 30, pricing_floor_cents: nil) }

        it "returns fit_status not_a_fit" do
          result = described_class.call(booking_request:, raw: base_raw.merge(headcount: 50))
          expect(result.attrs[:fit_status]).to eq("not_a_fit")
        end
      end

      context "when budget is below all spaces pricing floor" do
        before { create(:venue_space, venue:, min_guests: nil, capacity_reception: 100, pricing_floor_cents: 200000) }

        it "returns fit_status not_a_fit" do
          result = described_class.call(booking_request:, raw: base_raw.merge(budget: 500.0))
          expect(result.attrs[:fit_status]).to eq("not_a_fit")
        end
      end

      it "computes missing_fields for nil required values" do
        result = described_class.call(booking_request:, raw: base_raw.merge(event_date: nil, headcount: nil))
        expect(result.attrs[:missing_fields]).to include("event_date", "headcount")
        expect(result.attrs[:missing_fields]).not_to include("budget", "start_time", "celebration_type")
      end

      it "includes staff_summary string" do
        expect(result.attrs[:staff_summary]).to be_a(String).and be_present
      end

      it "passes through extractor fields" do
        expect(result.attrs[:event_date]).to eq(Date.new(2026, 6, 14))
        expect(result.attrs[:headcount]).to eq(40)
        expect(result.attrs[:budget]).to eq(500.0)
      end
    end

    describe "recommended_venue_space_id" do
      context "when no venue assigned" do
        let(:booking_request) { create(:booking_request, account:, venue: nil) }

        it "is nil" do
          expect(result.attrs[:recommended_venue_space_id]).to be_nil
        end
      end

      context "when venue has no spaces" do
        it "is nil" do
          expect(result.attrs[:recommended_venue_space_id]).to be_nil
        end
      end

      context "single qualifying space" do
        let!(:space) { create(:venue_space, venue:, min_guests: 20, capacity_reception: 100, pricing_floor_cents: nil) }

        it "populates recommended_venue_space_id" do
          expect(result.attrs[:recommended_venue_space_id]).to eq(space.id)
        end
      end

      context "private_space_preference tiebreak" do
        let!(:public_space) { create(:venue_space, venue:, min_guests: nil, max_guests: 100, private: false, pricing_floor_cents: nil) }
        let!(:private_space) { create(:venue_space, venue:, min_guests: nil, max_guests: 100, private: true, pricing_floor_cents: nil) }

        it "prefers private space when preference is private" do
          result = described_class.call(booking_request:, raw: base_raw.merge(private_space_preference: "private"))
          expect(result.attrs[:recommended_venue_space_id]).to eq(private_space.id)
        end

        it "prefers non-private space when preference is semi_private" do
          result = described_class.call(booking_request:, raw: base_raw.merge(private_space_preference: "semi_private"))
          expect(result.attrs[:recommended_venue_space_id]).to eq(public_space.id)
        end
      end

      context "duration tiebreak" do
        let!(:no_duration_space) { create(:venue_space, venue:, min_guests: nil, max_guests: 100, duration_options: [], pricing_floor_cents: 1000) }
        let!(:matching_duration_space) { create(:venue_space, venue:, min_guests: nil, max_guests: 100, duration_options: [ "2_hours", "all_night" ], pricing_floor_cents: 2000) }

        it "prefers space with matching duration option" do
          result = described_class.call(booking_request:, raw: base_raw.merge(duration: "2_hours"))
          expect(result.attrs[:recommended_venue_space_id]).to eq(matching_duration_space.id)
        end
      end

      context "feature_preferences tiebreak" do
        let!(:no_features_space) { create(:venue_space, venue:, min_guests: nil, max_guests: 100, features: [], pricing_floor_cents: nil) }
        let!(:matching_features_space) { create(:venue_space, venue:, min_guests: nil, max_guests: 100, features: [ "private_bar", "stage" ], pricing_floor_cents: nil) }

        it "prefers space with more feature overlap" do
          result = described_class.call(booking_request:, raw: base_raw.merge(feature_preferences: [ "private_bar" ]))
          expect(result.attrs[:recommended_venue_space_id]).to eq(matching_features_space.id)
        end
      end

      context "pricing tiebreak on equal score" do
        let!(:expensive_space) { create(:venue_space, venue:, min_guests: nil, max_guests: 100, pricing_floor_cents: 50000) }
        let!(:cheap_space) { create(:venue_space, venue:, min_guests: nil, max_guests: 100, pricing_floor_cents: 10000) }

        it "picks space with lower pricing_floor_cents" do
          expect(result.attrs[:recommended_venue_space_id]).to eq(cheap_space.id)
        end
      end

      context "no fitting space (exceeds all capacities)" do
        before { create(:venue_space, venue:, min_guests: nil, max_guests: 10, pricing_floor_cents: nil) }

        it "sets fit_status not_a_fit and leaves recommended_venue_space_id nil" do
          result = described_class.call(booking_request:, raw: base_raw.merge(headcount: 50))
          expect(result.attrs[:fit_status]).to eq("not_a_fit")
          expect(result.attrs[:recommended_venue_space_id]).to be_nil
        end
      end
    end
  end
end
