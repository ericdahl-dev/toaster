# frozen_string_literal: true

require "rails_helper"

RSpec.describe WaitlistEntry, type: :model do
  subject(:entry) { build(:waitlist_entry) }

  describe "validations" do
    it "is valid with all fields" do
      expect(entry).to be_valid
    end

    it "requires email" do
      entry.email = nil
      expect(entry).not_to be_valid
      expect(entry.errors[:email]).to be_present
    end

    it "requires full_name" do
      entry.full_name = nil
      expect(entry).not_to be_valid
      expect(entry.errors[:full_name]).to be_present
    end

    it "requires company_name" do
      entry.company_name = nil
      expect(entry).not_to be_valid
      expect(entry.errors[:company_name]).to be_present
    end

    it "rejects malformed email" do
      entry.email = "notanemail"
      expect(entry).not_to be_valid
      expect(entry.errors[:email]).to include("must be a valid email address")
    end

    it "rejects duplicate email (case-insensitive)" do
      create(:waitlist_entry, email: "owner@venue.com")
      entry.email = "OWNER@venue.com"
      expect(entry).not_to be_valid
    end
  end

  describe "status enum" do
    it "defaults to pending" do
      expect(described_class.new).to be_pending
    end

    it "transitions through the full lifecycle" do
      entry = create(:waitlist_entry)
      expect(entry).to be_pending
      entry.invited!
      expect(entry).to be_invited
      entry.converted!
      expect(entry).to be_converted
    end

    it "supports expired status" do
      entry = create(:waitlist_entry, status: :invited)
      entry.expired!
      expect(entry).to be_expired
    end
  end
end
