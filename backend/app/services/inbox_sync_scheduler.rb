# frozen_string_literal: true

# Single entry point for enqueueing inbox ingestion work so HTTP layers and
# fan-out jobs do not reference provider-specific job classes directly.
module InboxSyncScheduler
  module_function

  def schedule(connection)
    case connection
    when ImapConnection
      SyncImapJob.perform_later(connection.id)
    else
      raise ArgumentError, "InboxSyncScheduler does not support #{connection.class.name}"
    end
  end
end
