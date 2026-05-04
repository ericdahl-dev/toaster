require "rails_helper"

RSpec.describe "AgentMailbox inbox ingestion" do
  let(:account) { create(:account) }
  let(:connection) { create(:agentmail_connection, account: account) }

  def ingest(connection:, fetcher:)
    InboxIngestion::Sync.call(
      adapter: InboxIngestion::AgentMailboxAdapter.new(connection: connection, fetcher: fetcher)
    )
  end

  def stub_fetcher(messages)
    fetcher = instance_double(AgentMailbox::Fetcher)
    allow(fetcher).to receive(:fetch_messages).and_return(messages)
    fetcher
  end

  describe "InboxIngestion::Sync + AgentMailboxAdapter" do
    it "persists raw inbox messages from the fetcher" do
      fetcher = stub_fetcher([
        {
          provider: "agentmail",
          provider_message_id: "msg-1",
          provider_thread_id: "thread-1",
          direction: "inbound",
          from_email: "lead@example.com",
          from_name: "Lead Person",
          to_emails: ["agent@example.com"],
          subject: "Wedding inquiry",
          body_text: "Looking for a June date",
          received_at: Time.zone.parse("2026-04-01 10:00:00 UTC"),
          raw_payload: {"messageId" => "msg-1", "threadId" => "thread-1"}
        }
      ])

      result = ingest(connection: connection, fetcher: fetcher)

      expect(result.created_count).to eq(1)
      expect(result.deduped_count).to eq(0)

      message = InboxMessage.find_by!(account: account, provider_message_id: "msg-1")
      expect(message.provider_thread_id).to eq("thread-1")
      expect(message.direction).to eq("inbound")
      expect(message.from_email).to eq("lead@example.com")
      expect(message.subject).to eq("Wedding inquiry")
    end

    it "updates last_synced_at on the connection" do
      fetcher = stub_fetcher([])
      before = Time.current

      ingest(connection: connection, fetcher: fetcher)

      expect(connection.reload.last_synced_at).to be >= before
    end

    it "deduplicates by account, provider, and provider_message_id" do
      create(
        :inbox_message,
        account: account,
        provider: "agentmail",
        provider_message_id: "msg-1",
        subject: "Old subject"
      )

      fetcher = stub_fetcher([
        {
          provider: "agentmail",
          provider_message_id: "msg-1",
          provider_thread_id: "thread-1",
          direction: "inbound",
          from_email: "lead@example.com",
          subject: "Updated subject",
          raw_payload: {"messageId" => "msg-1"}
        }
      ])

      result = ingest(connection: connection, fetcher: fetcher)

      expect(result.created_count).to eq(0)
      expect(result.deduped_count).to eq(1)
      expect(InboxMessage.find_by!(account: account, provider_message_id: "msg-1").subject).to eq("Updated subject")
    end

    it "deduplicates a concurrent insert via RecordNotUnique" do
      existing = create(
        :inbox_message,
        account: account,
        provider: "agentmail",
        provider_message_id: "msg-race",
        subject: "Pre-existing subject"
      )

      fetcher = stub_fetcher([
        {
          provider: "agentmail",
          provider_message_id: "msg-race",
          provider_thread_id: "thread-1",
          direction: "inbound",
          from_email: "lead@example.com",
          subject: "Race condition subject",
          raw_payload: {"messageId" => "msg-race"}
        }
      ])

      call_count = 0
      allow(InboxMessage).to receive(:find_or_initialize_by).and_wrap_original do |original, **kwargs|
        call_count += 1
        record = original.call(**kwargs)
        allow(record).to receive(:save!).and_raise(ActiveRecord::RecordNotUnique) if call_count == 1
        record
      end
      allow(InboxMessage).to receive(:find_by!).with(
        account: account,
        provider: "agentmail",
        provider_message_id: "msg-race"
      ).and_return(existing)

      result = ingest(connection: connection, fetcher: fetcher)

      expect(result.created_count).to eq(0)
      expect(result.deduped_count).to eq(1)
    end
  end
end
