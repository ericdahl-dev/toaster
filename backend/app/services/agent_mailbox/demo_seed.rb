module AgentMailbox
  class DemoSeed
    Result = Struct.new(:account, :inbox_message, :booking_request, :summary, keyword_init: true)

    SAMPLE_PAYLOAD = {
      provider: "agent_mailbox",
      provider_message_id: "demo-msg-1",
      provider_thread_id: "demo-thread-1",
      direction: "inbound",
      from_email: "demo.lead@example.com",
      from_name: "Demo Lead",
      to_emails: ["agent@example.com"],
      subject: "Wedding for 120 guests on June 14, 2026",
      body_text: "Hi, we're looking for a venue on June 14, 2026 for 120 guests with a budget of $15000.",
      received_at: Time.zone.parse("2026-04-01 10:00:00 UTC"),
      raw_payload: {"messageId" => "demo-msg-1", "threadId" => "demo-thread-1"}
    }.freeze

    def self.call(account_name: "POC Demo Account")
      new(account_name: account_name).call
    end

    def initialize(account_name:)
      @account_name = account_name
    end

    def call
      account = Account.find_or_create_by!(name: account_name)

      sync_result = InboxIngestion::Sync.call(
        adapter: InboxIngestion::AgentMailboxAdapter.new(
          account: account,
          fetcher: StaticFetcher.new([SAMPLE_PAYLOAD])
        )
      )

      inbox_message = sync_result.messages.first ||
        account.inbox_messages.find_by!(
          provider: SAMPLE_PAYLOAD[:provider],
          provider_message_id: SAMPLE_PAYLOAD[:provider_message_id],
          provider_thread_id: SAMPLE_PAYLOAD[:provider_thread_id]
        )
      extraction = AgentMailbox::ExtractBookingRequest.call(inbox_message: inbox_message)

      Result.new(
        account: account,
        inbox_message: inbox_message,
        booking_request: extraction.booking_request,
        summary: summary_for(account, inbox_message, extraction.booking_request)
      )
    end

    private

    attr_reader :account_name

    def summary_for(account, inbox_message, booking_request)
      [
        "Seeded Toaster POC demo for #{account.name}",
        "Inbox message: #{inbox_message.provider_message_id}",
        "Booking request: #{booking_request.id}",
        "Headcount: #{booking_request.headcount}",
        "Event date: #{booking_request.event_date}",
        "Budget cents: #{booking_request.budget_cents}"
      ].join("\n")
    end

    class StaticFetcher
      def initialize(messages)
        @messages = messages
      end

      def fetch_messages
        @messages
      end
    end
  end
end
