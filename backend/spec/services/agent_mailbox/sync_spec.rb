require "rails_helper"

RSpec.describe AgentMailbox::Sync do
  describe ".call" do
    it "persists raw inbox messages from the fetcher" do
      account = create(:account)
      fetcher = instance_double(AgentMailbox::Fetcher)
      allow(fetcher).to receive(:fetch_messages).and_return([
        {
          provider: "agent_mailbox",
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

      result = described_class.call(account: account, fetcher: fetcher)

      expect(result.created_count).to eq(1)
      expect(result.deduped_count).to eq(0)

      message = InboxMessage.find_by!(account: account, provider_message_id: "msg-1")
      expect(message.provider_thread_id).to eq("thread-1")
      expect(message.direction).to eq("inbound")
      expect(message.from_email).to eq("lead@example.com")
      expect(message.subject).to eq("Wedding inquiry")
      expect(message.raw_payload).to include("messageId" => "msg-1")
    end

    it "deduplicates by account, provider, and provider_message_id" do
      account = create(:account)
      create(
        :inbox_message,
        account: account,
        provider: "agent_mailbox",
        provider_message_id: "msg-1",
        subject: "Old subject"
      )

      fetcher = instance_double(AgentMailbox::Fetcher)
      allow(fetcher).to receive(:fetch_messages).and_return([
        {
          provider: "agent_mailbox",
          provider_message_id: "msg-1",
          provider_thread_id: "thread-1",
          direction: "inbound",
          from_email: "lead@example.com",
          subject: "Updated subject",
          raw_payload: {"messageId" => "msg-1"}
        }
      ])

      result = described_class.call(account: account, fetcher: fetcher)

      expect(result.created_count).to eq(0)
      expect(result.deduped_count).to eq(1)
      expect(InboxMessage.where(account: account, provider: "agent_mailbox", provider_message_id: "msg-1").count).to eq(1)
      expect(InboxMessage.find_by!(account: account, provider_message_id: "msg-1").subject).to eq("Updated subject")
    end

    it "deduplicates a concurrent insert via RecordNotUnique (race condition)" do
      account = create(:account)
      fetcher = instance_double(AgentMailbox::Fetcher)
      allow(fetcher).to receive(:fetch_messages).and_return([
        {
          provider: "agent_mailbox",
          provider_message_id: "msg-race",
          provider_thread_id: "thread-1",
          direction: "inbound",
          from_email: "lead@example.com",
          subject: "Race condition subject",
          raw_payload: {"messageId" => "msg-race"}
        }
      ])

      # Simulate a concurrent insert: find_or_initialize_by returns a new record,
      # but save! raises RecordNotUnique because another worker inserted first.
      existing = create(
        :inbox_message,
        account: account,
        provider: "agent_mailbox",
        provider_message_id: "msg-race",
        subject: "Pre-existing subject"
      )

      call_count = 0
      allow(InboxMessage).to receive(:find_or_initialize_by).and_wrap_original do |original, **kwargs|
        call_count += 1
        record = original.call(**kwargs)
        # On first call, simulate a new record that raises on save due to a concurrent insert
        if call_count == 1
          allow(record).to receive(:save!).and_raise(ActiveRecord::RecordNotUnique)
        end
        record
      end
      allow(InboxMessage).to receive(:find_by).with(
        account: account,
        provider: "agent_mailbox",
        provider_message_id: "msg-race"
      ).and_return(existing)

      result = described_class.call(account: account, fetcher: fetcher)

      expect(result.created_count).to eq(0)
      expect(result.deduped_count).to eq(1)
    end
  end
end
