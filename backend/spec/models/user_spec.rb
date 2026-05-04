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

    it "is invalid with the same email on a different account" do
      create(:user, email: "test@example.com")
      account2 = create(:account)
      expect(build(:user, account: account2, email: "test@example.com")).not_to be_valid
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
  end

  describe "#remember" do
    it "returns a non-empty raw token" do
      user = create(:user)
      raw_token = user.remember
      expect(raw_token).to be_present
    end

    it "stores a digest on the user" do
      user = create(:user)
      user.remember
      expect(user.reload.remember_token_digest).to be_present
    end
  end

  describe "#forget" do
    it "clears the stored digest" do
      user = create(:user)
      user.remember
      user.forget
      expect(user.reload.remember_token_digest).to be_nil
    end
  end

  describe "#authenticated_by_token?" do
    it "returns true for a valid raw token" do
      user = create(:user)
      raw_token = user.remember
      expect(user.authenticated_by_token?(raw_token)).to be true
    end

    it "returns false for an invalid token" do
      user = create(:user)
      user.remember
      expect(user.authenticated_by_token?("wrong-token")).to be false
    end

    it "returns false when no digest is stored" do
      user = create(:user)
      expect(user.authenticated_by_token?("any-token")).to be false
    end
  end
end
