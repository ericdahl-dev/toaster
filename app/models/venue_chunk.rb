# frozen_string_literal: true

class VenueChunk < ApplicationRecord
  belongs_to :venue_document

  has_neighbors :embedding

  validates :content, presence: true
end
