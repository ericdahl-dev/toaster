class SyncAgentMailboxJob < ApplicationJob
  queue_as :webhooks

  retry_on StandardError, wait: :polynomially_longer, attempts: 5
  discard_on ActiveRecord::RecordNotFound

  def perform(agentmail_connection_id)
    connection = AgentmailConnection.find(agentmail_connection_id)
    result = InboxIngestion::Sync.call(
      adapter: InboxIngestion::AgentMailboxAdapter.new(connection: connection)
    )
    log_job_event(
      :agentmail_sync_result,
      connection_id: connection.id,
      created_count: result.created_count,
      deduped_count: result.deduped_count,
      last_synced_at: connection.reload.last_synced_at&.iso8601
    )
    result
  end
end
