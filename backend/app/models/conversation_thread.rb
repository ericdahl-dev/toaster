class ConversationThread < ApplicationRecord
  belongs_to :account
  belongs_to :contact

  has_many :booking_requests, dependent: :destroy
  has_many :messages, dependent: :destroy

  validates :gmail_thread_id, presence: true, uniqueness: { scope: :account_id }

  validate :contact_belongs_to_account

  private

  def contact_belongs_to_account
    return unless contact && account
    if contact.account_id != account_id
      errors.add(:contact, "must belong to the same account")
    end
  end
end
