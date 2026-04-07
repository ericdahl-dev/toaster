class SyncImapJob < ApplicationJob
  queue_as :webhooks

  retry_on StandardError, wait: :polynomially_longer, attempts: 5
  discard_on ActiveRecord::RecordNotFound

  def perform(imap_connection_id)
    connection = ImapConnection.find(imap_connection_id)
    Imap::Sync.call(imap_connection: connection)
  end
end
