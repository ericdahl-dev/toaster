# frozen_string_literal: true

require "rails_helper"

RSpec.describe BookingRequests::ExtractionLock do
  describe ".terminal?" do
    it "is true for confirmed and cancelled" do
      expect(described_class.terminal?(build(:booking_request, status: :confirmed))).to be(true)
      expect(described_class.terminal?(build(:booking_request, status: :cancelled))).to be(true)
    end

    it "is false for pending, reviewing, and nil" do
      expect(described_class.terminal?(build(:booking_request, status: :pending))).to be(false)
      expect(described_class.terminal?(build(:booking_request, status: :reviewing))).to be(false)
      expect(described_class.terminal?(nil)).to be(false)
    end
  end

  describe ".booking_request_for" do
    it "returns terminal booking request via shared thread lookup" do
      account = create(:account)
      inbox_message = create(:inbox_message, account: account, provider: "imap", provider_thread_id: "raw-1")
      contact = create(:contact, account: account)
      thread = create(
        :conversation_thread,
        account: account,
        contact: contact,
        provider_thread_id: ConversationThreading.canonical_id_for(inbox_message)
      )
      booking = create(:booking_request, account: account, conversation_thread: thread, status: :confirmed)

      expect(described_class.booking_request_for(inbox_message)).to eq(booking)
    end

    it "returns nil when booking request is not terminal" do
      account = create(:account)
      inbox_message = create(:inbox_message, account: account, provider: "imap", provider_thread_id: "raw-1")
      contact = create(:contact, account: account)
      thread = create(
        :conversation_thread,
        account: account,
        contact: contact,
        provider_thread_id: ConversationThreading.canonical_id_for(inbox_message)
      )
      create(:booking_request, account: account, conversation_thread: thread, status: :pending)

      expect(described_class.booking_request_for(inbox_message)).to be_nil
    end

    it "returns nil when thread row uses wrong provider_thread_id shape" do
      account = create(:account)
      inbox_message = create(:inbox_message, account: account, provider: "imap", provider_thread_id: "raw-1")
      contact = create(:contact, account: account)
      thread = create(:conversation_thread, account: account, contact: contact, provider_thread_id: "raw-1")
      create(:booking_request, account: account, conversation_thread: thread, status: :confirmed)

      expect(described_class.booking_request_for(inbox_message)).to be_nil
    end
  end
end
