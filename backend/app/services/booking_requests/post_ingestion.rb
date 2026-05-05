# frozen_string_literal: true

module BookingRequests
  # Orchestration after each {InboxMessage} is persisted by {InboxIngestion::Sync}.
  # See docs/adr/0001-post-ingestion-booking-reconcile.md.
  #
  # Status changes use {Transition} from API/ops/UI — not invoked here.
  module PostIngestion
    module_function

    def after_inbox_message_persisted(inbox_message)
      Reconcile.call(inbox_message: inbox_message)
    end
  end
end
