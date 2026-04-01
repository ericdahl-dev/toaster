require "rails_helper"

RSpec.describe Task, type: :model do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:thread) { create(:conversation_thread, account: account, contact: contact) }
  let(:booking_request) { create(:booking_request, account: account, contact: contact, conversation_thread: thread) }

  describe "validations" do
    it "is valid with valid attributes" do
      expect(build(:task, account: account, booking_request: booking_request)).to be_valid
    end

    it "is invalid without a title" do
      expect(build(:task, account: account, booking_request: booking_request, title: nil)).not_to be_valid
    end

    it "is invalid when booking_request belongs to different account" do
      other_account = create(:account)
      other_contact = create(:contact, account: other_account)
      other_thread = create(:conversation_thread, account: other_account, contact: other_contact)
      other_br = create(:booking_request, account: other_account, contact: other_contact, conversation_thread: other_thread)
      task = build(:task, account: account, booking_request: other_br)
      expect(task).not_to be_valid
      expect(task.errors[:booking_request]).to include("must belong to the same account")
    end
  end

  describe "enums" do
    it "has correct status values" do
      expect(Task.statuses).to eq({
        "open" => "open",
        "completed" => "completed",
        "cancelled" => "cancelled"
      })
    end
  end
end
