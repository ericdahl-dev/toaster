require "rails_helper"

RSpec.describe BookingRequest, type: :model do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:thread) { create(:conversation_thread, account: account, contact: contact) }

  describe "validations" do
    it "is valid with valid attributes" do
      expect(build(:booking_request, account: account, contact: contact, conversation_thread: thread)).to be_valid
    end

    it "is invalid with unknown status" do
      expect {
        build(:booking_request, account: account, contact: contact, conversation_thread: thread, status: "unknown")
      }.to raise_error(ArgumentError)
    end

    it "is invalid with non-positive headcount" do
      expect(build(:booking_request, account: account, contact: contact, conversation_thread: thread, headcount: 0)).not_to be_valid
    end

    it "is valid with positive headcount" do
      expect(build(:booking_request, account: account, contact: contact, conversation_thread: thread, headcount: 10)).to be_valid
    end

    it "is invalid with negative budget_cents" do
      expect(build(:booking_request, account: account, contact: contact, conversation_thread: thread, budget_cents: -1)).not_to be_valid
    end

    it "is valid with zero budget_cents" do
      expect(build(:booking_request, account: account, contact: contact, conversation_thread: thread, budget_cents: 0)).to be_valid
    end

    it "is invalid when event_end_date is before event_date" do
      br = build(:booking_request,
        account: account, contact: contact, conversation_thread: thread,
        event_date: Date.today + 10,
        event_end_date: Date.today + 5)
      expect(br).not_to be_valid
      expect(br.errors[:event_end_date]).to include("must be on or after event_date")
    end

    it "is valid when event_end_date equals event_date" do
      date = Date.today + 10
      expect(build(:booking_request,
        account: account, contact: contact, conversation_thread: thread,
        event_date: date,
        event_end_date: date)).to be_valid
    end

    it "is invalid when contact belongs to different account" do
      other_contact = create(:contact, account: create(:account))
      br = build(:booking_request, account: account, contact: other_contact, conversation_thread: thread)
      expect(br).not_to be_valid
      expect(br.errors[:contact]).to include("must belong to the same account")
    end

    it "is invalid when conversation_thread belongs to different account" do
      other_account = create(:account)
      other_contact = create(:contact, account: other_account)
      other_thread = create(:conversation_thread, account: other_account, contact: other_contact)
      br = build(:booking_request, account: account, contact: contact, conversation_thread: other_thread)
      expect(br).not_to be_valid
      expect(br.errors[:conversation_thread]).to include("must belong to the same account")
    end

    it "is invalid when venue belongs to different account" do
      venue = create(:venue, account: create(:account))
      br = build(:booking_request, account: account, contact: contact, conversation_thread: thread, venue: venue)
      expect(br).not_to be_valid
      expect(br.errors[:venue]).to include("must belong to the same account")
    end
  end

  describe "enums" do
    it "has correct status values" do
      expect(BookingRequest.statuses).to eq({
        "pending" => "pending",
        "reviewing" => "reviewing",
        "confirmed" => "confirmed",
        "rejected" => "rejected",
        "cancelled" => "cancelled"
      })
    end
  end

  describe "associations" do
    it "belongs to account" do
      br = create(:booking_request, account: account, contact: contact, conversation_thread: thread)
      expect(br.account).to eq(account)
    end

    it "has many drafts" do
      br = create(:booking_request, account: account, contact: contact, conversation_thread: thread)
      draft = create(:draft, account: account, booking_request: br)
      expect(br.drafts).to include(draft)
    end

    it "has many tasks" do
      br = create(:booking_request, account: account, contact: contact, conversation_thread: thread)
      task = create(:task, account: account, booking_request: br)
      expect(br.tasks).to include(task)
    end
  end
end
