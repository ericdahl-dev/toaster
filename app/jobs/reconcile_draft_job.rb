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
      create_outbound_message(draft, result)
      confirm_booking_request(draft.booking_request)
    end

    log_job_event(
      :draft_reconciled,
      draft_id: draft.id,
      outcome: result.outcome,
      similarity: result.similarity
    )
  end

  private

  def create_outbound_message(draft, result)
    booking_request = draft.booking_request
    Message.create!(
      account: draft.account,
      conversation_thread: booking_request.conversation_thread,
      booking_request: booking_request,
      direction: :outbound,
      body_text: result.sent_body,
      sent_at: draft.sent_at || Time.current
    )
  end

  def confirm_booking_request(booking_request)
    return unless booking_request.reviewing?
    BookingRequests::Transition.call(booking_request: booking_request, to: "confirmed", metadata: {actor: "reconcile_draft_job"})
  end
end
