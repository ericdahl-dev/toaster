# frozen_string_literal: true

require "rails_helper"

RSpec.describe BookingRequests::Decisioner do
  subject(:decisioner) { described_class }

  describe ".call" do
    let(:base) do
      {
        event_date: Date.new(2026, 6, 14),
        headcount: 40,
        budget: 500.0,
        start_time: "7:00 PM",
        celebration_type: "birthday",
        confidence: 0.95,
        notes: nil,
        fit_status: "qualified",
        missing_fields: [],
        staff_summary: "40 guests on 2026-06-14"
      }
    end

    it "returns pending when confidence is high and all fields present and qualified" do
      expect(decisioner.call(base)).to eq("pending")
    end

    it "returns reviewing when confidence is below threshold" do
      expect(decisioner.call(base.merge(confidence: 0.7))).to eq("reviewing")
    end

    it "returns reviewing when fit_status is not_a_fit" do
      expect(decisioner.call(base.merge(fit_status: "not_a_fit"))).to eq("reviewing")
    end

    it "returns reviewing when missing fields present" do
      expect(decisioner.call(base.merge(missing_fields: ["event_date"]))).to eq("reviewing")
    end

    it "returns reviewing when fit_status is in_progress" do
      expect(decisioner.call(base.merge(fit_status: "in_progress"))).to eq("reviewing")
    end

    it "returns pending when fit_status is nil (no venue configured)" do
      expect(decisioner.call(base.merge(fit_status: nil))).to eq("pending")
    end
  end
end
