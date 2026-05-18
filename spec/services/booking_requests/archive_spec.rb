# frozen_string_literal: true

require "rails_helper"

RSpec.describe BookingRequests::Archive do
  let(:account) { create(:account) }
  let(:booking_request) { create(:booking_request, account: account) }

  describe ".call" do
    it "sets archived_at on the booking request" do
      described_class.call(booking_request: booking_request)

      expect(booking_request.reload.archived_at).to be_within(1.second).of(Time.current)
    end

    it "creates an EventLog entry" do
      expect {
        described_class.call(booking_request: booking_request)
      }.to change(EventLog, :count).by(1)

      log = EventLog.last
      expect(log.event_type).to eq("booking_request.archived")
      expect(log.subject_id).to eq(booking_request.id)
    end

    it "is idempotent when already archived" do
      archived_at = 2.hours.ago
      booking_request.update!(archived_at: archived_at)

      expect {
        described_class.call(booking_request: booking_request)
      }.not_to change(EventLog, :count)

      expect(booking_request.reload.archived_at).to be_within(1.second).of(archived_at)
    end

    it "does not delete related messages, drafts, or tasks" do
      thread = booking_request.conversation_thread
      message = create(:message, account: account, conversation_thread: thread, booking_request: booking_request)
      draft = create(:draft, account: account, booking_request: booking_request)
      task = create(:task, account: account, booking_request: booking_request)

      described_class.call(booking_request: booking_request)

      expect(Message.exists?(message.id)).to be true
      expect(Draft.exists?(draft.id)).to be true
      expect(Task.exists?(task.id)).to be true
    end

    it "captures PostHog archive event" do
      expect(Telemetry).to receive(:capture).with(
        hash_including(
          event: "booking_request_archived",
          properties: hash_including(booking_request_id: booking_request.id, source: "manual")
        )
      )

      described_class.call(booking_request: booking_request, metadata: { distinct_id: "user_1" })
    end
  end
end
