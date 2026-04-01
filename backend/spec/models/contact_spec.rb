require "rails_helper"

RSpec.describe Contact, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      expect(build(:contact)).to be_valid
    end

    it "is invalid without a name" do
      expect(build(:contact, name: nil)).not_to be_valid
    end
  end

  describe "associations" do
    it "belongs to account" do
      contact = create(:contact)
      expect(contact.account).to be_a(Account)
    end

    it "has many conversation_threads" do
      account = create(:account)
      contact = create(:contact, account: account)
      thread = create(:conversation_thread, account: account, contact: contact)
      expect(contact.conversation_threads).to include(thread)
    end

    it "has many booking_requests" do
      account = create(:account)
      contact = create(:contact, account: account)
      thread = create(:conversation_thread, account: account, contact: contact)
      br = create(:booking_request, account: account, contact: contact, conversation_thread: thread)
      expect(contact.booking_requests).to include(br)
    end
  end
end
