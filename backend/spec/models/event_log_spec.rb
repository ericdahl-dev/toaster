require "rails_helper"

RSpec.describe EventLog, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      expect(build(:event_log)).to be_valid
    end

    it "is invalid without an event_type" do
      expect(build(:event_log, event_type: nil)).not_to be_valid
    end
  end

  describe "associations" do
    it "belongs to account" do
      event_log = create(:event_log)
      expect(event_log.account).to be_a(Account)
    end
  end
end
