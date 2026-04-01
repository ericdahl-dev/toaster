class GmailConnection < ApplicationRecord
  belongs_to :account
  belongs_to :user

  validates :email, presence: true, uniqueness: { scope: :account_id, case_sensitive: false }
  validates :active, inclusion: { in: [true, false] }

  validate :user_belongs_to_account

  WATCH_RENEWAL_THRESHOLD = 24.hours

  scope :active_connections, -> { where(active: true) }
  scope :expired_watch, -> { where("watch_expiration IS NULL OR watch_expiration <= ?", Time.current) }
  scope :expiring_watch_soon, -> { where("watch_expiration BETWEEN ? AND ?", Time.current, Time.current + WATCH_RENEWAL_THRESHOLD) }
  scope :healthy, -> { active_connections.where("watch_expiration > ?", Time.current) }

  def token_expired?
    token_expires_at.present? && token_expires_at <= Time.current
  end

  def watch_active?
    watch_expiration.present? && watch_expiration > Time.current
  end

  def watch_expired?
    watch_expiration.nil? || watch_expiration <= Time.current
  end

  def watch_expires_soon?
    return false unless watch_active?
    watch_expiration <= Time.current + WATCH_RENEWAL_THRESHOLD
  end

  def healthy?
    active? && !token_expired? && watch_active?
  end

  private

  def user_belongs_to_account
    return unless user && account
    if user.account_id != account_id
      errors.add(:user, "must belong to the same account")
    end
  end
end
