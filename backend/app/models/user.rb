class User < ApplicationRecord
  belongs_to :account

  validates :email, presence: true, uniqueness: {scope: :account_id, case_sensitive: false}
  validates :name, presence: true
end
