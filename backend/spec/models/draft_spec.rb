require "rails_helper"

RSpec.describe Draft, type: :model do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:thread) { create(:conversation_thread, account: account, contact: contact) }
  let(:booking_request) { create(:booking_request, account: account, contact: contact, conversation_thread: thread) }

  describe "validations" do
    it "is valid with valid attributes" do
      expect(build(:draft, account: account, booking_request: booking_request)).to be_valid
    end

    it "is invalid without a body" do
      expect(build(:draft, account: account, booking_request: booking_request, body: nil)).not_to be_valid
    end

    it "is invalid when booking_request belongs to different account" do
      other_account = create(:account)
      other_contact = create(:contact, account: other_account)
      other_thread = create(:conversation_thread, account: other_account, contact: other_contact)
      other_br = create(:booking_request, account: other_account, contact: other_contact, conversation_thread: other_thread)
      draft = build(:draft, account: account, booking_request: other_br)
      expect(draft).not_to be_valid
      expect(draft.errors[:booking_request]).to include("must belong to the same account")
    end
  end

  describe "enums" do
    it "has correct status values" do
      expect(Draft.statuses).to eq({
        "pending_review" => "pending_review",
        "approved" => "approved",
        "modified" => "modified",
        "rejected" => "rejected",
        "sent" => "sent"
      })
    end
  end
end
