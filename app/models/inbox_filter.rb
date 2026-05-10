# frozen_string_literal: true

class InboxFilter < ApplicationRecord
  belongs_to :imap_connection
  belongs_to :venue

  validates :keyword, presence: true
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  default_scope { order(:position) }
end
