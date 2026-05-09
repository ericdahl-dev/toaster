# frozen_string_literal: true

class Venue < ApplicationRecord
  belongs_to :account

  has_many :booking_requests, dependent: :nullify
  has_many :venue_spaces, dependent: :destroy
  has_many :venue_documents, dependent: :destroy

  accepts_nested_attributes_for :venue_spaces,
    allow_destroy: true,
    reject_if: :all_blank

  validates :name, presence: true
  validates :capacity, numericality: {greater_than: 0, allow_nil: true}
end
