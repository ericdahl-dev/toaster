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
