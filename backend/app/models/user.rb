# frozen_string_literal: true

class User < ApplicationRecord
  belongs_to :account

  has_secure_password

  before_validation :normalize_email

  validates :email, presence: true, uniqueness: true
  validates :name, presence: true

  # Generates a random token, stores its digest, and returns the raw token.
  def remember
    raw_token = SecureRandom.urlsafe_base64(32)
    update_columns(remember_token_digest: BCrypt::Password.create(raw_token))
    raw_token
  end

  # Clears the stored remember-token digest so any existing cookies are invalidated.
  def forget
    update_columns(remember_token_digest: nil)
  end

  # Returns true if +raw_token+ matches the stored digest.
  def authenticated_by_token?(raw_token)
    return false if remember_token_digest.nil?

    BCrypt::Password.new(remember_token_digest).is_password?(raw_token)
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase if email.present?
  end
end
