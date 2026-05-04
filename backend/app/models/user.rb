class User < ApplicationRecord
  belongs_to :account

  has_secure_password

  before_validation :normalize_email

  validates :email, presence: true, uniqueness: true
  validates :name, presence: true

  private

  def normalize_email
    self.email = email.to_s.strip.downcase if email.present?
  end
end
