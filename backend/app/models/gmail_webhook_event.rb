class GmailWebhookEvent < ApplicationRecord
  belongs_to :account

  validates :raw_payload, presence: true

  scope :unprocessed, -> { where(processed_at: nil) }
  scope :processed, -> { where.not(processed_at: nil) }

  def processed?
    processed_at.present?
  end
end
