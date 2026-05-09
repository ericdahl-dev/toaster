class EventLog < ApplicationRecord
  belongs_to :account

  validates :event_type, presence: true
  validates :payload, presence: true
end
