class BookingRequest < ApplicationRecord
  belongs_to :account
  belongs_to :conversation_thread
  belongs_to :contact
  belongs_to :venue, optional: true
  belongs_to :source_inbox_message, class_name: "InboxMessage", optional: true

  has_many :messages, dependent: :nullify
  has_many :drafts, dependent: :destroy
  has_many :tasks, dependent: :destroy
  has_many :ai_runs, dependent: :destroy

  enum :status, {
    pending: "pending",
    reviewing: "reviewing",
    confirmed: "confirmed",
    rejected: "rejected",
    cancelled: "cancelled"
  }

  validates :status, presence: true
  validates :headcount, numericality: {greater_than: 0, allow_nil: true}
  validates :budget, numericality: {greater_than_or_equal_to: 0, allow_nil: true}
  validate :event_date_range_valid
  validate :contact_belongs_to_account
  validate :conversation_thread_belongs_to_account
  validate :venue_belongs_to_account
  validate :source_inbox_message_belongs_to_account

  private

  def event_date_range_valid
    return unless event_date && event_end_date
    if event_end_date < event_date
      errors.add(:event_end_date, "must be on or after event_date")
    end
  end

  def contact_belongs_to_account
    return unless contact && account
    if contact.account_id != account_id
      errors.add(:contact, "must belong to the same account")
    end
  end

  def conversation_thread_belongs_to_account
    return unless conversation_thread && account
    if conversation_thread.account_id != account_id
      errors.add(:conversation_thread, "must belong to the same account")
    end
  end

  def venue_belongs_to_account
    return unless venue && account
    if venue.account_id != account_id
      errors.add(:venue, "must belong to the same account")
    end
  end

  def source_inbox_message_belongs_to_account
    return unless source_inbox_message && account
    if source_inbox_message.account_id != account_id
      errors.add(:source_inbox_message, "must belong to the same account")
    end
  end
end
