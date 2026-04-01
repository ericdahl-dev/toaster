require "rails_helper"

RSpec.describe GmailConnection, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      account = create(:account)
      user = create(:user, account: account)
      expect(build(:gmail_connection, account: account, user: user)).to be_valid
    end

    it "is invalid without an email" do
      account = create(:account)
      user = create(:user, account: account)
      expect(build(:gmail_connection, account: account, user: user, email: nil)).not_to be_valid
    end

    it "is invalid with duplicate email within same account" do
      account = create(:account)
      user = create(:user, account: account)
      create(:gmail_connection, account: account, user: user, email: "test@gmail.com")
      user2 = create(:user, account: account)
      expect(build(:gmail_connection, account: account, user: user2, email: "test@gmail.com")).not_to be_valid
    end

    it "is invalid when user belongs to different account" do
      account1 = create(:account)
      account2 = create(:account)
      user = create(:user, account: account2)
      connection = build(:gmail_connection, account: account1, user: user)
      expect(connection).not_to be_valid
      expect(connection.errors[:user]).to include("must belong to the same account")
    end
  end

  describe "associations" do
    it "belongs to account" do
      connection = create(:gmail_connection)
      expect(connection.account).to be_a(Account)
    end

    it "belongs to user" do
      connection = create(:gmail_connection)
      expect(connection.user).to be_a(User)
    end
  end
end
