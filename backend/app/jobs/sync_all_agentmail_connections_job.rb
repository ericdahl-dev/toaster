# frozen_string_literal: true

class SyncAllAgentmailConnectionsJob < ApplicationJob
  queue_as :webhooks

  def perform
    enqueued_count = 0

    AgentmailConnection.active_connections.find_each do |conn|
      SyncAgentMailboxJob.perform_later(conn.id)
      enqueued_count += 1
    end

    log_job_event(:agentmail_fanout_enqueued, enqueued_count: enqueued_count)
  end
end
