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

    context "when configured? returns true" do
      before { allow(described_class).to receive(:configured?).and_return(true) }

      it "calls PostHog.capture" do
        expect(PostHog).to receive(:capture).with(distinct_id: "user-1", event: "test_event", properties: {})
        described_class.capture(distinct_id: "user-1", event: "test_event")
      end

      it "rescues PostHog errors and logs a warning" do
        allow(PostHog).to receive(:capture).and_raise(RuntimeError, "network failure")
        expect(Rails.logger).to receive(:warn).with(/capture failed/)
        described_class.capture(distinct_id: "user-1", event: "test_event")
      end
    end
  end

  describe ".capture_exception" do
    it "does not call PostHog in the test environment" do
      expect(PostHog).not_to receive(:capture_exception)
      described_class.capture_exception(StandardError.new("boom"), "user-1")
    end

    context "when configured? returns true" do
      before { allow(described_class).to receive(:configured?).and_return(true) }

      it "calls PostHog.capture_exception" do
        err = StandardError.new("boom")
        expect(PostHog).to receive(:capture_exception).with(err, "user-1")
        described_class.capture_exception(err, "user-1")
      end

      it "rescues PostHog errors and logs a warning" do
        allow(PostHog).to receive(:capture_exception).and_raise(RuntimeError, "network failure")
        expect(Rails.logger).to receive(:warn).with(/capture_exception failed/)
        described_class.capture_exception(StandardError.new("boom"), "user-1")
      end
    end
  end

  describe ".identify" do
    it "does not call PostHog in the test environment" do
      expect(PostHog).not_to receive(:identify)
      described_class.identify(distinct_id: "user-1", properties: { name: "Test" })
    end

    context "when configured? returns true" do
      before { allow(described_class).to receive(:configured?).and_return(true) }

      it "calls PostHog.identify" do
        expect(PostHog).to receive(:identify).with(distinct_id: "user-1", properties: { name: "Test" })
        described_class.identify(distinct_id: "user-1", properties: { name: "Test" })
      end

      it "rescues PostHog errors and logs a warning" do
        allow(PostHog).to receive(:identify).and_raise(RuntimeError, "network failure")
        expect(Rails.logger).to receive(:warn).with(/identify failed/)
        described_class.identify(distinct_id: "user-1")
      end
    end
  end
end
