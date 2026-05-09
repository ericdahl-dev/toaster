# frozen_string_literal: true

class VenueSpace < ApplicationRecord
  belongs_to :venue

  validates :name, presence: true
  validates :capacity_seated, numericality: {greater_than: 0, allow_nil: true}
  validates :capacity_reception, numericality: {greater_than: 0, allow_nil: true}
  validates :min_guests, numericality: {greater_than: 0, allow_nil: true}
  validates :pricing_floor_cents, numericality: {greater_than_or_equal_to: 0, allow_nil: true}
end
