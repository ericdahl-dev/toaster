class Contact < ApplicationRecord
  belongs_to :account

  has_many :conversation_threads, dependent: :destroy
  has_many :booking_requests, dependent: :destroy

  validates :name, presence: true
end
