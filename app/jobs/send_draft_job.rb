# frozen_string_literal: true

class SendDraftJob < ApplicationJob
  queue_as :mailers

  retry_on Drafts::SmtpSender::SendError, wait: :polynomially_longer, attempts: 5
  discard_on ActiveRecord::RecordNotFound

  def perform(draft_id)
    draft = Draft.find(draft_id)
    return unless draft.pending_review?

    imap_connection = draft.account.imap_connections.active_connections.first
    return unless imap_connection

    Drafts::SmtpSender.call(draft: draft, imap_connection: imap_connection)
    create_outbound_message(draft)
    confirm_booking_request(draft.booking_request)
  end

  private

  def create_outbound_message(draft)
    booking_request = draft.booking_request
    Message.create!(
      account: draft.account,
      conversation_thread: booking_request.conversation_thread,
      booking_request: booking_request,
      direction: :outbound,
      body_text: draft.body,
      sent_at: draft.reload.sent_at || Time.current
    )
  end

  def confirm_booking_request(booking_request)
    booking_request.confirmed! if booking_request.reviewing?
  end
end
