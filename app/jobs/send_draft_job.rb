# frozen_string_literal: true

class SendDraftJob < ApplicationJob
  queue_as :mailers

  retry_on Drafts::SmtpSender::SendError, wait: :polynomially_longer, attempts: 5
  discard_on ActiveRecord::RecordNotFound

  def perform(draft_id)
    draft = Draft.find(draft_id)
    return unless draft.pending_review? || draft.approved?

    imap_connection = draft.account.imap_connections.active_connections.first
    return unless imap_connection

    Drafts::SmtpSender.call(draft: draft, imap_connection: imap_connection)
    Drafts::CompleteSend.call(
      draft: draft.reload,
      sent_body: draft.body,
      actor: "send_draft_job"
    )
  end
end
