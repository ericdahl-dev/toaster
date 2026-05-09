class SyncAllImapConnectionsJob < ApplicationJob
  queue_as :webhooks

  def perform
    enqueued_count = 0

    ImapConnection.active_connections.find_each do |conn|
      InboxSyncScheduler.schedule(conn)
      enqueued_count += 1
    end

    log_job_event(:imap_fanout_enqueued, enqueued_count: enqueued_count)
  end
end
