class SyncAgentMailboxJob < ApplicationJob
  queue_as :webhooks

  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  def perform(account_id)
    account = Account.find(account_id)
    AgentMailbox::Sync.call(account: account)
  end
end
