class Account < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :imap_connections, dependent: :destroy
  has_many :contacts, dependent: :destroy
  has_many :venues, dependent: :destroy
  has_many :conversation_threads, dependent: :destroy
  has_many :booking_requests, dependent: :destroy
  has_many :messages, dependent: :destroy
  has_many :inbox_messages, dependent: :destroy
  has_many :drafts, dependent: :destroy
  has_many :tasks, dependent: :destroy
  has_many :event_logs, dependent: :destroy
  has_many :ai_runs, dependent: :destroy

  validates :name, presence: true

  def onboarded?
    onboarded_at? || (venues.exists? && imap_connections.exists?)
  end

  def complete_onboarding!
    return if onboarded_at?
    update_column(:onboarded_at, Time.current)
  end
end
