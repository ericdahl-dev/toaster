class SendDraftJob < ApplicationJob
  queue_as :mailers

  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(draft_id)
    draft = Draft.find(draft_id)
    return unless draft.approved?

    # Outbound provider not integrated yet; status advance matches current ops/send contract.
    draft.update!(status: :sent)
  end
end
