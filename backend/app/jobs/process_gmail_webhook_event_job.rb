class ProcessGmailWebhookEventJob < ApplicationJob
  queue_as :webhooks

  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  def perform(webhook_event_id)
    event = GmailWebhookEvent.find(webhook_event_id)
    return if event.processed?

    # TODO: parse raw_payload and sync new messages via Gmail API
    event.update!(processed_at: Time.current)
  end
end
