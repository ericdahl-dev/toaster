require "rails_helper"

RSpec.describe User, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      expect(build(:user)).to be_valid
    end

    it "is invalid without an email" do
      expect(build(:user, email: nil)).not_to be_valid
    end

    it "is invalid without a name" do
      expect(build(:user, name: nil)).not_to be_valid
    end

    it "is invalid with duplicate email within same account" do
      account = create(:account)
      create(:user, account: account, email: "test@example.com")
      expect(build(:user, account: account, email: "test@example.com")).not_to be_valid
    end

    it "is valid with same email in different accounts" do
      create(:user, email: "test@example.com")
      account2 = create(:account)
      expect(build(:user, account: account2, email: "test@example.com")).to be_valid
    end

    it "treats emails case-insensitively for uniqueness" do
      account = create(:account)
      create(:user, account: account, email: "test@example.com")
      expect(build(:user, account: account, email: "TEST@EXAMPLE.COM")).not_to be_valid
    end
  end

  describe "associations" do
    it "belongs to account" do
      user = create(:user)
      expect(user.account).to be_a(Account)
    end

    it "has many gmail_connections" do
      account = create(:account)
      user = create(:user, account: account)
      connection = create(:gmail_connection, account: account, user: user)
      expect(user.gmail_connections).to include(connection)
    end
  end
end
