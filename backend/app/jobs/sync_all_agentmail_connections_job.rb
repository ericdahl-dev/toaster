# frozen_string_literal: true

class SyncAllAgentmailConnectionsJob < ApplicationJob
  queue_as :webhooks

  def perform
    AgentmailConnection.active_connections.find_each do |conn|
      SyncAgentMailboxJob.perform_later(conn.id)
    end
  end
end
