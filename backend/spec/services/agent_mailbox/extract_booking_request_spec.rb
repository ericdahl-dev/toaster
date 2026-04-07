require "rails_helper"

RSpec.describe AgentMailbox::ExtractBookingRequest do
  describe ".call" do
    it "creates a minimal booking request snapshot for a happy-path inbox message" do
      account = create(:account)
      inbox_message = create(
        :inbox_message,
        account: account,
        provider_thread_id: "thread-123",
        provider_message_id: "msg-123",
        from_name: "Jamie Lead",
        from_email: "jamie@example.com",
        subject: "Wedding for 120 guests on June 14, 2026",
        body_text: "Hi, we're looking for a venue for 120 guests on June 14, 2026 with a budget of $15000.",
        received_at: Time.zone.parse("2026-04-01 10:00:00 UTC")
      )

      result = described_class.call(inbox_message: inbox_message)

      booking_request = result.booking_request
      expect(booking_request).to be_persisted
      expect(booking_request.account).to eq(account)
      expect(booking_request.source_inbox_message).to eq(inbox_message)
      expect(booking_request.contact.email).to eq("jamie@example.com")
      expect(booking_request.conversation_thread.provider_thread_id).to eq("agent_mailbox:thread-123")
      expect(booking_request.event_date).to eq(Date.new(2026, 6, 14))
      expect(booking_request.headcount).to eq(120)
      expect(booking_request.budget_cents).to eq(1_500_000)
      expect(booking_request.status).to eq("pending")
      expect(booking_request.missing_fields).to eq([])
      expect(booking_request.review_reasons).to eq([])
      expect(booking_request.extraction_snapshot).to include(
        "event_date" => "2026-06-14",
        "headcount" => 120,
        "budget_cents" => 1_500_000
      )

      message = Message.find_by!(booking_request: booking_request)
      expect(message.direction).to eq("inbound")
      expect(message.provider_message_id).to eq("agent_mailbox:msg-123")
      expect(message.body_text).to include("budget of $15000")
    end

    it "records missing fields and falls back to reviewing when key fields are absent" do
      account = create(:account)
      inbox_message = create(
        :inbox_message,
        account: account,
        provider_thread_id: "thread-456",
        provider_message_id: "msg-456",
        from_name: "Taylor Lead",
        from_email: "taylor@example.com",
        subject: "Private event inquiry",
        body_text: "Hi, we're planning an event and want to learn more about availability."
      )

      result = described_class.call(inbox_message: inbox_message)

      booking_request = result.booking_request
      expect(booking_request.status).to eq("reviewing")
      expect(booking_request.missing_fields).to match_array(%w[event_date headcount budget_cents])
      expect(booking_request.review_reasons).to eq([])
      expect(booking_request.extraction_snapshot).to include(
        "event_date" => nil,
        "headcount" => nil,
        "budget_cents" => nil
      )
    end

    it "records ambiguous fields and falls back to reviewing instead of guessing" do
      account = create(:account)
      inbox_message = create(
        :inbox_message,
        account: account,
        provider_thread_id: "thread-789",
        provider_message_id: "msg-789",
        from_name: "Morgan Lead",
        from_email: "morgan@example.com",
        subject: "Event inquiry for June 14 or June 21",
        body_text: "We're planning for either June 14, 2026 or June 21, 2026 for about 80 guests with a budget of $8000."
      )

      result = described_class.call(inbox_message: inbox_message)

      booking_request = result.booking_request
      expect(booking_request.status).to eq("reviewing")
      expect(booking_request.event_date).to be_nil
      expect(booking_request.review_reasons).to include("ambiguous_event_date")
      expect(booking_request.missing_fields).to include("event_date")
      expect(booking_request.headcount).to eq(80)
      expect(booking_request.budget_cents).to eq(800_000)
    end

    it "uses the inbox message provider to namespace canonical thread and message ids" do
      account = create(:account)
      inbox_message = create(
        :inbox_message,
        account: account,
        provider: "imap",
        provider_thread_id: "<thread@domain.com>",
        provider_message_id: "<msg@domain.com>",
        from_email: "guest@example.com",
        subject: "Event for 60 guests on July 4, 2026",
        body_text: "Looking for a venue for 60 guests on July 4, 2026 with a budget of $6000."
      )

      result = described_class.call(inbox_message: inbox_message)

      expect(result.conversation_thread.provider_thread_id).to eq("imap:<thread@domain.com>")
      expect(result.message.provider_message_id).to eq("imap:<msg@domain.com>")
    end
  end
end
