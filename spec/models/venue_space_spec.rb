# frozen_string_literal: true

require "rails_helper"

RSpec.describe VenueSpace, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      expect(build(:venue_space)).to be_valid
    end

    it "is invalid without a name" do
      expect(build(:venue_space, name: nil)).not_to be_valid
    end

    it "validates max_guests numericality when present" do
      expect(build(:venue_space, max_guests: 0)).not_to be_valid
      expect(build(:venue_space, max_guests: -1)).not_to be_valid
      expect(build(:venue_space, max_guests: 50)).to be_valid
      expect(build(:venue_space, max_guests: nil)).to be_valid
    end
  end

  describe "new intake fields" do
    it "defaults duration_options to empty array" do
      space = create(:venue_space)
      expect(space.duration_options).to eq([])
    end

    it "defaults private to false" do
      space = create(:venue_space)
      expect(space.private).to be false
    end

    it "stores duration_options as array" do
      space = create(:venue_space, duration_options: [ "2_hours", "all_night" ])
      expect(space.reload.duration_options).to eq([ "2_hours", "all_night" ])
    end

    it "stores features as array" do
      space = create(:venue_space, features: [ "private_bar", "stage" ])
      expect(space.reload.features).to eq([ "private_bar", "stage" ])
    end

    it "defaults features to empty array" do
      space = create(:venue_space)
      expect(space.features).to eq([])
    end

    it "stores max_guests" do
      space = create(:venue_space, max_guests: 150)
      expect(space.reload.max_guests).to eq(150)
    end

    it "stores private flag" do
      space = create(:venue_space, private: true)
      expect(space.reload.private).to be true
    end
  end
end
