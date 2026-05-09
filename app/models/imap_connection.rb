class ImapConnection < ApplicationRecord
  belongs_to :account

  has_many :inbox_filters, dependent: :destroy

  validates :host, presence: true
  validates :port, presence: true, numericality: {only_integer: true, greater_than: 0}
  validates :username, presence: true
  validates :username, uniqueness: {scope: [:account_id, :host], case_sensitive: false}
  validates :inbox_folder, presence: true
  validates :active, inclusion: {in: [true, false]}

  scope :active_connections, -> { where(active: true) }
end
