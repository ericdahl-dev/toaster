# frozen_string_literal: true

module AgentMailbox
  class ConnectionsController < AccountScopedController
    include MailConnections

    private

    def connections_scope
      @account.agentmail_connections
    end

    def connection_params
      params.require(:agentmail_connection).permit(:inbox_id, :api_key, :active)
    end

    def connection_json(connection)
      {
        id: connection.id,
        inbox_id: connection.inbox_id,
        active: connection.active,
        last_synced_at: connection.last_synced_at,
        created_at: connection.created_at,
        updated_at: connection.updated_at
      }
    end
  end
end
