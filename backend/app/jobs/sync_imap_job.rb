class SyncImapJob < ApplicationJob
  queue_as :webhooks

  retry_on StandardError, wait: :polynomially_longer, attempts: 5
  discard_on ActiveRecord::RecordNotFound

  def perform(imap_connection_id)
    connection = ImapConnection.find(imap_connection_id)
    result = Imap::Sync.call(imap_connection: connection)
    log_job_event(
      :imap_sync_result,
      connection_id: connection.id,
      created_count: result.created_count,
      deduped_count: result.deduped_count,
      last_synced_uid: connection.reload.last_synced_uid
    )
    result
  end
end
