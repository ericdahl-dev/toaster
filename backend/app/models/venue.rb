class Venue < ApplicationRecord
  belongs_to :account

  has_many :booking_requests, dependent: :nullify

  validates :name, presence: true
  validates :capacity, numericality: { greater_than: 0, allow_nil: true }
end
