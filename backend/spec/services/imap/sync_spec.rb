require "rails_helper"

RSpec.describe Imap::Sync do
  describe ".call" do
    it "persists IMAP inbox messages from the fetcher" do
      account = create(:account)
      connection = create(:imap_connection, account: account)
      fetcher = instance_double(Imap::Fetcher)

      allow(fetcher).to receive(:fetch_messages).and_return([
        {
          provider: "imap",
          provider_message_id: "<msg-1@example.com>",
          provider_thread_id: "<msg-1@example.com>",
          direction: "inbound",
          from_email: "lead@example.com",
          from_name: "Lead Person",
          to_emails: [ "agent@example.com" ],
          subject: "Wedding inquiry",
          body_text: "Looking for a June date",
          received_at: Time.zone.parse("2026-04-01 10:00:00 UTC"),
          raw_payload: { "uid" => 1, "message_id" => "<msg-1@example.com>" }
        }
      ])

      result = described_class.call(imap_connection: connection, fetcher: fetcher)

      expect(result.created_count).to eq(1)
      expect(result.deduped_count).to eq(0)

      message = InboxMessage.find_by!(account: account, provider: "imap", provider_message_id: "<msg-1@example.com>")
      expect(message.from_email).to eq("lead@example.com")
      expect(message.subject).to eq("Wedding inquiry")
      expect(message.provider_thread_id).to eq("<msg-1@example.com>")
    end

    it "updates last_synced_uid after fetching messages" do
      account = create(:account)
      connection = create(:imap_connection, account: account, last_synced_uid: nil)
      fetcher = instance_double(Imap::Fetcher)

      allow(fetcher).to receive(:fetch_messages).and_return([
        {
          provider: "imap",
          provider_message_id: "<msg-1@example.com>",
          direction: "inbound",
          from_email: "lead@example.com",
          subject: "Inquiry",
          raw_payload: { "uid" => 5, "message_id" => "<msg-1@example.com>" }
        }
      ])

      described_class.call(imap_connection: connection, fetcher: fetcher)

      expect(connection.reload.last_synced_uid).to eq(5)
    end

    it "deduplicates by account, provider, and provider_message_id" do
      account = create(:account)
      connection = create(:imap_connection, account: account)
      create(
        :inbox_message,
        account: account,
        provider: "imap",
        provider_message_id: "<msg-1@example.com>",
        subject: "Old subject"
      )

      fetcher = instance_double(Imap::Fetcher)
      allow(fetcher).to receive(:fetch_messages).and_return([
        {
          provider: "imap",
          provider_message_id: "<msg-1@example.com>",
          direction: "inbound",
          from_email: "lead@example.com",
          subject: "Updated subject",
          raw_payload: { "uid" => 1 }
        }
      ])

      result = described_class.call(imap_connection: connection, fetcher: fetcher)

      expect(result.created_count).to eq(0)
      expect(result.deduped_count).to eq(1)
      expect(InboxMessage.where(account: account, provider: "imap", provider_message_id: "<msg-1@example.com>").count).to eq(1)
    end

    it "handles a concurrent insert via RecordNotUnique" do
      account = create(:account)
      connection = create(:imap_connection, account: account)
      fetcher = instance_double(Imap::Fetcher)

      allow(fetcher).to receive(:fetch_messages).and_return([
        {
          provider: "imap",
          provider_message_id: "<race@example.com>",
          direction: "inbound",
          from_email: "lead@example.com",
          subject: "Race condition",
          raw_payload: { "uid" => 10 }
        }
      ])

      existing = create(
        :inbox_message,
        account: account,
        provider: "imap",
        provider_message_id: "<race@example.com>"
      )

      call_count = 0
      allow(InboxMessage).to receive(:find_or_initialize_by).and_wrap_original do |original, **kwargs|
        call_count += 1
        record = original.call(**kwargs)
        allow(record).to receive(:save!).and_raise(ActiveRecord::RecordNotUnique) if call_count == 1
        record
      end
      allow(InboxMessage).to receive(:find_by!).with(
        account: account,
        provider: "imap",
        provider_message_id: "<race@example.com>"
      ).and_return(existing)

      result = described_class.call(imap_connection: connection, fetcher: fetcher)

      expect(result.created_count).to eq(0)
      expect(result.deduped_count).to eq(1)
    end

    it "returns empty result when no messages are fetched" do
      account = create(:account)
      connection = create(:imap_connection, account: account)
      fetcher = instance_double(Imap::Fetcher)
      allow(fetcher).to receive(:fetch_messages).and_return([])

      result = described_class.call(imap_connection: connection, fetcher: fetcher)

      expect(result.created_count).to eq(0)
      expect(result.deduped_count).to eq(0)
      expect(result.messages).to be_empty
    end
  end
end
