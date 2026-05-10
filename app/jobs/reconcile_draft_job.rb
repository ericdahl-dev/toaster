# frozen_string_literal: true

class ReconcileDraftJob < ApplicationJob
  queue_as :mailers

  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  SENT_OUTCOMES = %i[approved modified].freeze

  def perform(draft_id)
    draft = Draft.find(draft_id)
    return unless draft.pending_review? && draft.imap_draft_uid.present?

    imap_connection = draft.account.imap_connections.active_connections.first
    return unless imap_connection

    result = Drafts::SentMailReconciler.call(draft: draft, imap_connection: imap_connection)

    if SENT_OUTCOMES.include?(result.outcome)
      Drafts::CompleteSend.call(
        draft: draft,
        sent_body: result.sent_body,
        actor: "reconcile_draft_job"
      )
    end

    log_job_event(
      :draft_reconciled,
      draft_id: draft.id,
      outcome: result.outcome,
      similarity: result.similarity
    )
  end
end
