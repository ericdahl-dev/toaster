# frozen_string_literal: true

class WaitlistEntry < ApplicationRecord
  validates :email, presence: true, format: {with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address"}
  validates :email, uniqueness: {case_sensitive: false}
  validates :full_name, presence: true
  validates :company_name, presence: true

  enum :status, {pending: "pending", invited: "invited", converted: "converted", expired: "expired"}, default: "pending"
end
