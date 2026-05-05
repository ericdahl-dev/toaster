class User < ApplicationRecord
  REMEMBER_TOKEN_BYTES = 32
  REMEMBER_DURATION = 2.weeks

  belongs_to :account

  has_secure_password

  before_validation :normalize_email

  validates :email, presence: true, uniqueness: true
  validates :name, presence: true

  # Returns raw token for the signed cookie; persists bcrypt digest only.
  def issue_remember_token!
    raw = self.class.new_remember_token
    update!(remember_token_digest: self.class.digest_remember_token(raw))
    raw
  end

  def clear_remember_token!
    update_columns(remember_token_digest: nil) if remember_token_digest.present?
  end

  def valid_remember_token?(raw)
    return false if remember_token_digest.blank? || raw.blank?

    BCrypt::Password.new(remember_token_digest).is_password?(raw)
  rescue BCrypt::Errors::InvalidHash
    false
  end

  def self.new_remember_token
    SecureRandom.urlsafe_base64(REMEMBER_TOKEN_BYTES)
  end

  def self.digest_remember_token(token)
    BCrypt::Password.create(token, cost: BCrypt::Engine.cost)
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase if email.present?
  end
end
