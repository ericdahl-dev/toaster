class SendDraftJob < ApplicationJob
  queue_as :mailers

  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(draft_id)
    PushDraftJob.perform_later(draft_id)
  end
end
