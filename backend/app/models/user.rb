class User < ApplicationRecord
  belongs_to :account

  has_many :gmail_connections, dependent: :destroy

  validates :email, presence: true, uniqueness: {scope: :account_id, case_sensitive: false}
  validates :name, presence: true
end
