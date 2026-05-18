# frozen_string_literal: true

require "rails_helper"

RSpec.describe BookingRequests::ThreadLookup do
  describe ".conversation_thread_for" do
    it "finds thread by canonical provider_thread_id" do
      account = create(:account)
      inbox_message = create(:inbox_message, account: account, provider: "imap", provider_thread_id: "raw-1")
      contact = create(:contact, account: account)
      thread = create(
        :conversation_thread,
        account: account,
        contact: contact,
        provider_thread_id: ConversationThreading.canonical_id_for(inbox_message)
      )

      expect(described_class.conversation_thread_for(inbox_message)).to eq(thread)
    end

    it "returns nil when thread row uses raw id without provider prefix (wrong key)" do
      account = create(:account)
      inbox_message = create(:inbox_message, account: account, provider: "imap", provider_thread_id: "raw-1")
      contact = create(:contact, account: account)
      create(:conversation_thread, account: account, contact: contact, provider_thread_id: "raw-1")

      expect(described_class.conversation_thread_for(inbox_message)).to be_nil
    end
  end

  describe ".booking_request_for" do
    it "returns first booking request on resolved thread" do
      account = create(:account)
      inbox_message = create(:inbox_message, account: account, provider: "imap", provider_thread_id: "raw-1")
      contact = create(:contact, account: account)
      thread = create(
        :conversation_thread,
        account: account,
        contact: contact,
        provider_thread_id: ConversationThreading.canonical_id_for(inbox_message)
      )
      booking = create(:booking_request, account: account, conversation_thread: thread, status: :pending)

      expect(described_class.booking_request_for(inbox_message)).to eq(booking)
    end
  end
end
