# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ops::ActivityFeed do
  let(:account) { create(:account) }

  def make_thread_message(provider_thread_id:, received_at: 1.hour.ago, **attrs)
    create(:inbox_message,
      account: account,
      provider: "imap",
      provider_thread_id: provider_thread_id,
      received_at: received_at,
      **attrs)
  end

  def make_singleton_message(received_at: 1.hour.ago, **attrs)
    create(:inbox_message,
      account: account,
      provider: "imap",
      provider_thread_id: nil,
      received_at: received_at,
      **attrs)
  end

  describe ".call" do
    it "returns an array" do
      expect(described_class.call).to be_an(Array)
    end

    it "returns rows with named accessors" do
      make_thread_message(provider_thread_id: "t1")
      rows = described_class.call
      row = rows.first
      expect(row).to respond_to(:account_id)
      expect(row).to respond_to(:provider)
      expect(row).to respond_to(:kind)
      expect(row).to respond_to(:provider_thread_id)
      expect(row).to respond_to(:anchor_inbox_message_id)
      expect(row).to respond_to(:last_activity_at)
    end

    it "groups messages by thread" do
      make_thread_message(provider_thread_id: "t1", received_at: 2.hours.ago)
      make_thread_message(provider_thread_id: "t1", received_at: 1.hour.ago)
      make_thread_message(provider_thread_id: "t2", received_at: 3.hours.ago)

      rows = described_class.call
      expect(rows.size).to eq(2)
      thread_ids = rows.map(&:provider_thread_id)
      expect(thread_ids).to contain_exactly("t1", "t2")
    end

    it "sorts by last_activity_at descending" do
      make_thread_message(provider_thread_id: "older", received_at: 3.hours.ago)
      make_thread_message(provider_thread_id: "newer", received_at: 1.hour.ago)

      rows = described_class.call
      expect(rows.map(&:provider_thread_id)).to eq(["newer", "older"])
    end

    it "handles singleton messages (no provider_thread_id)" do
      msg = make_singleton_message(received_at: 1.hour.ago)
      rows = described_class.call

      row = rows.first
      expect(row.kind).to eq("singleton")
      expect(row.anchor_inbox_message_id).to eq(msg.id)
      expect(row.provider_thread_id).to be_nil
    end

    it "merges draft peaks into activity timestamps" do
      msg = make_thread_message(provider_thread_id: "t1", received_at: 5.hours.ago)
      br = create(:booking_request,
        account: account,
        source_inbox_message_id: msg.id,
        conversation_thread: create(:conversation_thread, account: account, provider_thread_id: "t1"))
      draft = create(:draft, account: account, booking_request: br,
        status: "pending_review",
        created_at: 30.minutes.ago)

      rows = described_class.call
      row = rows.find { |r| r.provider_thread_id == "t1" }
      expect(row.last_activity_at).to be_within(1.second).of(draft.created_at)
    end

    it "respects the limit parameter" do
      6.times { |i| make_thread_message(provider_thread_id: "t#{i}") }
      rows = described_class.call(limit: 3)
      expect(rows.size).to eq(3)
    end
  end
end
