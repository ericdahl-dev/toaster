class Task < ApplicationRecord
  belongs_to :account
  belongs_to :booking_request

  enum :status, {
    open: "open",
    completed: "completed",
    cancelled: "cancelled"
  }

  validates :title, presence: true
  validates :status, presence: true

  validate :booking_request_belongs_to_account

  private

  def booking_request_belongs_to_account
    return unless booking_request && account
    if booking_request.account_id != account_id
      errors.add(:booking_request, "must belong to the same account")
    end
  end
end
