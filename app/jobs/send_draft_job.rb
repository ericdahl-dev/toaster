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
    attrs = Drafts::MailBuilder.new(draft: draft).build_outbound_message_attrs(
      body_text: draft.body,
      sent_at: draft.reload.sent_at || Time.current
    )
    Message.create!(attrs)
  end

  def confirm_booking_request(booking_request)
    return unless booking_request.reviewing?
    BookingRequests::Transition.call(booking_request: booking_request, to: "confirmed", metadata: {actor: "send_draft_job"})
  end
end
