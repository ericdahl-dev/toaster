# frozen_string_literal: true

require "rails_helper"

RSpec.describe BookingRequests::ExtractionLock do
  describe ".terminal?" do
    it "is true for confirmed and cancelled" do
      expect(described_class.terminal?(build(:booking_request, status: :confirmed))).to be(true)
      expect(described_class.terminal?(build(:booking_request, status: :cancelled))).to be(true)
    end

    it "is false for pending, reviewing, and nil" do
      expect(described_class.terminal?(build(:booking_request, status: :pending))).to be(false)
      expect(described_class.terminal?(build(:booking_request, status: :reviewing))).to be(false)
      expect(described_class.terminal?(nil)).to be(false)
    end
  end
end
