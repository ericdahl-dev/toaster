require "rails_helper"

RSpec.describe Message, type: :model do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:thread) { create(:conversation_thread, account: account, contact: contact) }

  describe "validations" do
    it "is valid with valid attributes" do
      expect(build(:message, account: account, conversation_thread: thread)).to be_valid
    end

    it "is invalid without a direction" do
      expect(build(:message, account: account, conversation_thread: thread, direction: nil)).not_to be_valid
    end

    it "is invalid when conversation_thread belongs to different account" do
      other_account = create(:account)
      other_contact = create(:contact, account: other_account)
      other_thread = create(:conversation_thread, account: other_account, contact: other_contact)
      msg = build(:message, account: account, conversation_thread: other_thread)
      expect(msg).not_to be_valid
      expect(msg.errors[:conversation_thread]).to include("must belong to the same account")
    end

    it "is invalid when booking_request belongs to different account" do
      other_account = create(:account)
      other_contact = create(:contact, account: other_account)
      other_thread = create(:conversation_thread, account: other_account, contact: other_contact)
      other_br = create(:booking_request, account: other_account, contact: other_contact, conversation_thread: other_thread)
      msg = build(:message, account: account, conversation_thread: thread, booking_request: other_br)
      expect(msg).not_to be_valid
      expect(msg.errors[:booking_request]).to include("must belong to the same account")
    end
  end

  describe "enums" do
    it "has inbound and outbound directions" do
      expect(Message.directions).to eq({"inbound" => "inbound", "outbound" => "outbound"})
    end
  end

  describe "associations" do
    it "belongs to account" do
      msg = create(:message, account: account, conversation_thread: thread)
      expect(msg.account).to eq(account)
    end
  end
end
