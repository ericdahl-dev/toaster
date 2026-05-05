# frozen_string_literal: true

module BookingRequests
  # Runs after InboxIngestion::Sync persists a message (docs/adr/0001-post-ingestion-booking-reconcile.md).
  # Skips BookingRequests::Transition — human-driven status changes stay in API/ops/UI.
  module PostIngestion
    module_function

    def after_inbox_message_persisted(inbox_message)
      Reconcile.call(inbox_message: inbox_message)
    end
  end
end
