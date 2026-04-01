class SendDraftJob < ApplicationJob
  queue_as :mailers

  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(draft_id)
    draft = Draft.find(draft_id)
    return unless draft.approved?

    # TODO: send the draft via Gmail API and mark it sent
    draft.update!(status: :sent)
  end
end
