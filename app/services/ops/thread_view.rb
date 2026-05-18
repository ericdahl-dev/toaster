# frozen_string_literal: true

module Ops
  # Ops JSON adapter for inbox thread detail. See InboxThreads::Read for the shared read model.
  class ThreadView
    def self.call(**kwargs)
      InboxThreads::Read.detail(
        account_id: kwargs.fetch(:account_id),
        provider: kwargs.fetch(:provider),
        inbox_thread_id: kwargs[:provider_thread_id],
        anchor_inbox_message_id: kwargs[:anchor_inbox_message_id]
      )
    end
  end
end
