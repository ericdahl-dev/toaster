require "rails_helper"

RSpec.describe Venue, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      expect(build(:venue)).to be_valid
    end

    it "is invalid without a name" do
      expect(build(:venue, name: nil)).not_to be_valid
    end

    it "is invalid with non-positive capacity" do
      expect(build(:venue, capacity: 0)).not_to be_valid
      expect(build(:venue, capacity: -1)).not_to be_valid
    end

    it "is valid with nil capacity" do
      expect(build(:venue, capacity: nil)).to be_valid
    end
  end

  describe "associations" do
    it "belongs to account" do
      venue = create(:venue)
      expect(venue.account).to be_a(Account)
    end

    it "nullifies booking_requests when destroyed" do
      account = create(:account)
      venue = create(:venue, account: account)
      contact = create(:contact, account: account)
      thread = create(:conversation_thread, account: account, contact: contact)
      br = create(:booking_request, account: account, contact: contact, conversation_thread: thread, venue: venue)
      venue.destroy
      expect(br.reload.venue_id).to be_nil
    end
  end
end
