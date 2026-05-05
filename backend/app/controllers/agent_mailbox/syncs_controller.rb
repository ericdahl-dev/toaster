module AgentMailbox
  class SyncsController < AccountScopedController
    def create
      connections = @account.agentmail_connections.active_connections
      connections.each { |conn| InboxSyncScheduler.schedule(conn) }

      render json: {
        status: "enqueued",
        account_id: @account.id,
        connection_count: connections.size
      }, status: :accepted
    end
  end
end
