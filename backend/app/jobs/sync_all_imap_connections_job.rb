class SyncAllImapConnectionsJob < ApplicationJob
  queue_as :webhooks

  def perform
    ImapConnection.active_connections.find_each do |conn|
      SyncImapJob.perform_later(conn.id)
    end
  end
end
