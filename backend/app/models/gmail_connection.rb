class GmailConnection < ApplicationRecord
  belongs_to :account
  belongs_to :user

  validates :email, presence: true, uniqueness: { scope: :account_id, case_sensitive: false }
  validates :active, inclusion: { in: [true, false] }

  validate :user_belongs_to_account

  private

  def user_belongs_to_account
    return unless user && account
    if user.account_id != account_id
      errors.add(:user, "must belong to the same account")
    end
  end
end
