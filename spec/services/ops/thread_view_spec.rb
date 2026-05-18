# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ops::ThreadView do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:convo) { create(:conversation_thread, account: account, contact: contact, provider_thread_id: "imap:t-view") }
  let(:inbound) do
    create(:inbox_message,
      account: account,
      provider: "imap",
      provider_thread_id: "t-view",
      provider_message_id: "in-1",
      direction: :inbound,
      received_at: 3.days.ago)
  end
  let(:outbound) do
    create(:inbox_message,
      account: account,
      provider: "imap",
      provider_thread_id: "t-view",
      provider_message_id: "out-1",
      direction: :outbound,
      from_email: "venue@example.com",
      received_at: 2.days.ago)
  end
  let(:booking) do
    create(:booking_request,
      account: account,
      contact: contact,
      conversation_thread: convo,
      source_inbox_message: inbound)
  end
  let!(:draft) do
    create(:draft,
      account: account,
      booking_request: booking,
      status: :pending_review,
      body: "Draft reply",
      created_at: 1.day.ago)
  end

  def call(params)
    described_class.call(
      account_id: params[:account_id],
      provider: params[:provider],
      provider_thread_id: params[:provider_thread_id],
      anchor_inbox_message_id: params[:anchor_inbox_message_id]
    )
  end

  before do
    inbound
    outbound
    booking
  end

  describe ".call with a provider_thread_id" do
    subject(:result) do
      call(account_id: account.id, provider: "imap", provider_thread_id: "t-view")
    end

    it "returns a hash with kind: thread" do
      expect(result[:kind]).to eq("thread")
    end

    it "returns a chronologically ordered timeline" do
      sort_times = result[:timeline].map { |i| i[:sort_at] }
      expect(sort_times).to eq(sort_times.sort)
    end

    it "includes both inbox_message and draft types in timeline" do
      types = result[:timeline].map { |i| i[:type] }
      expect(types).to include("inbox_message", "draft")
    end

    it "includes booking_request summary" do
      expect(result[:booking_request]).to include(id: booking.id)
    end

    it "marks pending_review draft as not collapsed" do
      draft_item = result[:timeline].find { |i| i[:type] == "draft" }
      expect(draft_item[:default_collapsed]).to be(false)
    end
  end

  describe ".call with an anchor_inbox_message_id (singleton thread)" do
    let(:singleton_msg) do
      create(:inbox_message,
        account: account,
        provider: "imap",
        provider_thread_id: nil,
        provider_message_id: "solo-1",
        direction: :inbound,
        received_at: 1.day.ago)
    end
    let(:singleton_booking) do
      create(:booking_request,
        account: account,
        source_inbox_message: singleton_msg)
    end
    before { singleton_booking }

    subject(:result) do
      call(account_id: account.id, provider: "imap", anchor_inbox_message_id: singleton_msg.id)
    end

    it "returns kind: singleton" do
      expect(result[:kind]).to eq("singleton")
    end

    it "includes the anchor message in the timeline" do
      expect(result[:timeline].map { |i| i[:id] }).to include(singleton_msg.id)
    end
  end

  describe ".call with unknown thread" do
    it "raises ActiveRecord::RecordNotFound" do
      expect {
        call(account_id: account.id, provider: "imap", provider_thread_id: "no-such-thread")
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
