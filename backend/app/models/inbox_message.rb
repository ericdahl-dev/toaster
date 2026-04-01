class InboxMessage < ApplicationRecord
  belongs_to :account

  enum :direction, { inbound: "inbound", outbound: "outbound" }

  validates :provider, presence: true
  validates :provider_message_id, presence: true, uniqueness: { scope: [ :account_id, :provider ] }
  validates :direction, presence: true
end
