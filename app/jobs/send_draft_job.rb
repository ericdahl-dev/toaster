# frozen_string_literal: true

class SendDraftJob < ApplicationJob
  include GoodJob::ActiveJobExtensions::Concurrency

  queue_as :mailers

  good_job_control_concurrency_with(
    total_limit: 1,
    key: -> { "SendDraftJob/#{arguments.first}" }
  )

  retry_on Drafts::SmtpSender::SendError, wait: :polynomially_longer, attempts: 5
  discard_on ActiveRecord::RecordNotFound

  def perform(draft_id)
    draft = Draft.find(draft_id)
    return if draft.sent?

    draft.with_lock do
      draft.reload
      return if draft.sent?
      return unless draft.pending_review? || draft.approved?

      draft.update!(status: :approved) if draft.pending_review?
    end

    draft.reload
    return unless draft.approved?

    imap_connection = draft.account.imap_connections.active_connections.first
    unless imap_connection
      EventLog.create!(
        account: draft.account,
        event_type: "draft.send_skipped_no_connection",
        payload: { draft_id: draft.id, account_id: draft.account_id }
      )
      return
    end

    begin
      Drafts::SmtpSender.call(draft: draft, imap_connection: imap_connection)
    rescue Drafts::SmtpSender::SendError => e
      Telemetry.capture_exception(e, "account_#{draft.account_id}")
      Telemetry.capture(
        distinct_id: "account_#{draft.account_id}",
        event: "draft_send_failed",
        properties: {
          draft_id: draft.id,
          booking_request_id: draft.booking_request_id,
          imap_connection_id: imap_connection.id,
          error_class: e.class.name,
          error_message: e.message,
          attempt: executions
        }
      )
      raise
    end

    Drafts::CompleteSend.call(
      draft: draft.reload,
      sent_body: draft.body,
      actor: "send_draft_job"
    )

    Telemetry.capture(
      distinct_id: "account_#{draft.account_id}",
      event: "draft_sent",
      properties: {
        draft_id: draft.id,
        booking_request_id: draft.booking_request_id,
        imap_connection_id: imap_connection.id
      }
    )
  end
end
