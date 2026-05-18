# frozen_string_literal: true

require "rails_helper"

RSpec.describe InboxThreads::Read do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:convo) { create(:conversation_thread, account: account, contact: contact, provider_thread_id: "imap:t-read") }
  let!(:inbound) do
    create(:inbox_message,
      account: account,
      provider: "imap",
      provider_thread_id: "t-read",
      provider_message_id: "in-1",
      direction: :inbound,
      received_at: 3.days.ago)
  end
  let!(:booking) do
    create(:booking_request,
      account: account,
      contact: contact,
      conversation_thread: convo,
      source_inbox_message: inbound)
  end

  describe ".detail" do
    it "returns thread detail keyed by inbox_thread_id" do
      result = described_class.detail(account_id: account.id, provider: "imap", inbox_thread_id: "t-read")

      expect(result[:kind]).to eq("thread")
      expect(result[:provider_thread_id]).to eq("t-read")
      expect(result[:booking_request]).to include(id: booking.id)
    end
  end

  describe ".bookings_by_inbox_thread_id" do
    it "groups bookings by inbox-native thread id" do
      row = Ops::ActivityFeed::Row.new(
        account.id, "imap", "thread", "t-read", nil, 1.hour.ago
      )

      grouped = described_class.bookings_by_inbox_thread_id([ row ])

      expect(grouped["t-read"].map(&:id)).to eq([ booking.id ])
    end
  end
end
