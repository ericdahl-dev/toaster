# frozen_string_literal: true

class User < ApplicationRecord
  devise :database_authenticatable, :recoverable, :rememberable, :trackable, :validatable

  belongs_to :account

  enum :role, { venue_manager: 0, admin: 1 }, default: :venue_manager

  validates :name, presence: true

  before_validation :normalize_email

  # Used by posthog-rails for automatic user association in error reports.
  def posthog_distinct_id
    email
  end

  # Used when calling PostHog.identify to set person properties.
  def posthog_properties
    { email: email, role: role, account_id: account_id, date_joined: created_at&.iso8601 }
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase if email.present?
  end
end
