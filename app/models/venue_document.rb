# frozen_string_literal: true

class VenueDocument < ApplicationRecord
  belongs_to :venue
  has_many :venue_chunks, dependent: :destroy

  validates :source_filename, presence: true

  enum :status, { pending: "pending", processing: "processing", ready: "ready", failed: "failed" }, default: "pending"
end
