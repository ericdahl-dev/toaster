# frozen_string_literal: true

class AgentmailConnection < ApplicationRecord
  belongs_to :account

  validates :inbox_id, presence: true, uniqueness: {scope: :account_id, case_sensitive: false}
  validates :api_key, presence: true
  validates :active, inclusion: {in: [true, false]}

  scope :active_connections, -> { where(active: true) }
end
