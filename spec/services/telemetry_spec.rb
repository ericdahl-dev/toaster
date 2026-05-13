# frozen_string_literal: true

require "rails_helper"

RSpec.describe Telemetry do
  describe ".configured?" do
    it "returns false in the test environment" do
      expect(described_class.configured?).to be false
    end
  end

  describe ".capture" do
    it "does not call PostHog in the test environment" do
      expect(PostHog).not_to receive(:capture)
      described_class.capture(distinct_id: "user-1", event: "test_event")
    end
  end

  describe ".capture_exception" do
    it "does not call PostHog in the test environment" do
      expect(PostHog).not_to receive(:capture_exception)
      described_class.capture_exception(StandardError.new("boom"), "user-1")
    end
  end
end
