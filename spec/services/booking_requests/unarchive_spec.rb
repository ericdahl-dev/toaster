# frozen_string_literal: true

require "rails_helper"

RSpec.describe BookingRequests::Unarchive do
  let(:account) { create(:account) }
  let(:booking_request) { create(:booking_request, account: account, archived_at: 1.hour.ago) }

  describe ".call" do
    it "clears archived_at on the booking request" do
      described_class.call(booking_request: booking_request)

      expect(booking_request.reload.archived_at).to be_nil
    end

    it "creates an EventLog entry with source" do
      described_class.call(booking_request: booking_request, metadata: { source: "inbound" })

      expect(EventLog.last.event_type).to eq("booking_request.unarchived")
      expect(EventLog.last.payload).to include("source" => "inbound")
    end
  end
end
