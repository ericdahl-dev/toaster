class SyncAgentMailboxJob < ApplicationJob
  queue_as :webhooks

  retry_on StandardError, wait: :polynomially_longer, attempts: 5
  discard_on ActiveRecord::RecordNotFound

  def perform(agentmail_connection_id)
    connection = AgentmailConnection.find(agentmail_connection_id)
    AgentMailbox::Sync.call(connection: connection)
  end
end
