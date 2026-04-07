class Message < ApplicationRecord
  belongs_to :account
  belongs_to :conversation_thread
  belongs_to :booking_request, optional: true

  enum :direction, { inbound: "inbound", outbound: "outbound" }

  validates :direction, presence: true
  validates :provider_message_id, uniqueness: { scope: :account_id }, allow_nil: true

  validate :conversation_thread_belongs_to_account
  validate :booking_request_belongs_to_account

  private

  def conversation_thread_belongs_to_account
    return unless conversation_thread && account
    if conversation_thread.account_id != account_id
      errors.add(:conversation_thread, "must belong to the same account")
    end
  end

  def booking_request_belongs_to_account
    return unless booking_request && account
    if booking_request.account_id != account_id
      errors.add(:booking_request, "must belong to the same account")
    end
  end
end
