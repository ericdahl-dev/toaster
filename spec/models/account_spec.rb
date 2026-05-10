require "rails_helper"

RSpec.describe Account, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      expect(build(:account)).to be_valid
    end

    it "is invalid without a name" do
      expect(build(:account, name: nil)).not_to be_valid
    end
  end

  describe "#onboarded?" do
    it "returns true when onboarded_at is set" do
      account = build(:account, onboarded_at: Time.current)
      expect(account.onboarded?).to be true
    end

    it "returns false when onboarded_at is nil and no venues or connections" do
      account = create(:account, onboarded_at: nil)
      expect(account.onboarded?).to be false
    end

    it "returns true when account has venue and mail connection" do
      account = create(:account, onboarded_at: nil)
      create(:venue, account: account)
      create(:imap_connection, account: account)
      expect(account.onboarded?).to be true
    end

    it "does NOT stamp onboarded_at (pure predicate, no side effects)" do
      account = create(:account, onboarded_at: nil)
      create(:venue, account: account)
      create(:imap_connection, account: account)
      account.onboarded?
      expect(account.reload.onboarded_at).to be_nil
    end

    it "returns false when account has venue but no mail connection" do
      account = create(:account, onboarded_at: nil)
      create(:venue, account: account)
      expect(account.onboarded?).to be false
    end

    it "returns false when account has mail connection but no venue" do
      account = create(:account, onboarded_at: nil)
      create(:imap_connection, account: account)
      expect(account.onboarded?).to be false
    end
  end

  describe "#complete_onboarding!" do
    it "stamps onboarded_at" do
      account = create(:account, onboarded_at: nil)
      account.complete_onboarding!
      expect(account.reload.onboarded_at).not_to be_nil
    end

    it "is idempotent — does not overwrite an existing timestamp" do
      t = 1.day.ago
      account = create(:account, onboarded_at: t)
      account.complete_onboarding!
      expect(account.reload.onboarded_at).to be_within(1.second).of(t)
    end
  end

  describe "associations" do
    it "has many users" do
      account = create(:account)
      user = create(:user, account: account)
      expect(account.users).to include(user)
    end

    it "destroys users when destroyed" do
      account = create(:account)
      create(:user, account: account)
      expect { account.destroy }.to change(User, :count).by(-1)
    end

    it "has many contacts" do
      account = create(:account)
      contact = create(:contact, account: account)
      expect(account.contacts).to include(contact)
    end

    it "has many venues" do
      account = create(:account)
      venue = create(:venue, account: account)
      expect(account.venues).to include(venue)
    end
  end
end
