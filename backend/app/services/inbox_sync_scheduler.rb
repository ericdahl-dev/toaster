# frozen_string_literal: true

# Enqueue ingestion by connection type so callers do not name IMAP vs AgentMail job classes.
module InboxSyncScheduler
  module_function

  def schedule(connection)
    case connection
    when ImapConnection
      SyncImapJob.perform_later(connection.id)
    when AgentmailConnection
      SyncAgentMailboxJob.perform_later(connection.id)
    else
      raise ArgumentError, "InboxSyncScheduler does not support #{connection.class.name}"
    end
  end
end
