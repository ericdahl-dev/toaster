class PushDraftJob < ApplicationJob
  queue_as :mailers

  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound
  discard_on Drafts::ImapDraftPusher::FolderNotFound

  def perform(draft_id)
    draft = Draft.find(draft_id)
    return unless draft.pending_review?

    imap_connection = draft.account.imap_connections.active_connections.first
    return unless imap_connection

    Drafts::ImapDraftPusher.call(draft: draft, imap_connection: imap_connection)

    log_job_event(
      :draft_pushed_to_imap,
      draft_id: draft.id,
      imap_connection_id: imap_connection.id,
      imap_draft_uid: draft.reload.imap_draft_uid
    )
  end
end
