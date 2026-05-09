class InboxMessage < ApplicationRecord
  belongs_to :account

  has_one :booking_request, foreign_key: :source_inbox_message_id, dependent: :nullify

  enum :direction, {inbound: "inbound", outbound: "outbound"}

  validates :provider, presence: true
  validates :provider_message_id, presence: true, uniqueness: {scope: [:account_id, :provider]}
  validates :direction, presence: true
end
