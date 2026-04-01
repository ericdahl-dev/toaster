require "rails_helper"

RSpec.describe ConversationThread, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      expect(build(:conversation_thread)).to be_valid
    end

    it "is invalid without a gmail_thread_id" do
      expect(build(:conversation_thread, gmail_thread_id: nil)).not_to be_valid
    end

    it "is invalid with duplicate gmail_thread_id within same account" do
      account = create(:account)
      contact = create(:contact, account: account)
      create(:conversation_thread, account: account, contact: contact, gmail_thread_id: "thread_abc")
      contact2 = create(:contact, account: account)
      expect(build(:conversation_thread, account: account, contact: contact2, gmail_thread_id: "thread_abc")).not_to be_valid
    end

    it "is valid with same gmail_thread_id in different accounts" do
      account1 = create(:account)
      account2 = create(:account)
      contact1 = create(:contact, account: account1)
      contact2 = create(:contact, account: account2)
      create(:conversation_thread, account: account1, contact: contact1, gmail_thread_id: "thread_abc")
      expect(build(:conversation_thread, account: account2, contact: contact2, gmail_thread_id: "thread_abc")).to be_valid
    end

    it "is invalid when contact belongs to different account" do
      account1 = create(:account)
      account2 = create(:account)
      contact = create(:contact, account: account2)
      thread = build(:conversation_thread, account: account1, contact: contact)
      expect(thread).not_to be_valid
      expect(thread.errors[:contact]).to include("must belong to the same account")
    end
  end

  describe "associations" do
    it "belongs to account" do
      thread = create(:conversation_thread)
      expect(thread.account).to be_a(Account)
    end

    it "belongs to contact" do
      thread = create(:conversation_thread)
      expect(thread.contact).to be_a(Contact)
    end
  end
end
