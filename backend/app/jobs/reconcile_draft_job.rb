class ReconcileDraftJob < ApplicationJob
  queue_as :mailers

  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(draft_id)
    draft = Draft.find(draft_id)
    return unless draft.pending_review? && draft.imap_draft_uid.present?

    imap_connection = draft.account.imap_connections.active_connections.first
    return unless imap_connection

    result = Drafts::SentMailReconciler.call(draft: draft, imap_connection: imap_connection)

    log_job_event(
      :draft_reconciled,
      draft_id: draft.id,
      outcome: result.outcome,
      similarity: result.similarity
    )
  end
end
