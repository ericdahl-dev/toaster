class Account < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :gmail_connections, dependent: :destroy
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
  has_many :gmail_webhook_events, dependent: :destroy
  has_many :ai_runs, dependent: :destroy

  validates :name, presence: true
end
