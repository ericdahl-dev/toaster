class AiRun < ApplicationRecord
  belongs_to :account
  belongs_to :booking_request, optional: true

  validates :llm_model, presence: true
  validates :prompt, presence: true

  # model_name conflicts with ActiveRecord::Base.model_name; use llm_model column via explicit accessors
  def model_name
    llm_model
  end

  def model_name=(value)
    self.llm_model = value
  end

  validate :booking_request_belongs_to_account

  private

  def booking_request_belongs_to_account
    return unless booking_request && account
    if booking_request.account_id != account_id
      errors.add(:booking_request, "must belong to the same account")
    end
  end
end
