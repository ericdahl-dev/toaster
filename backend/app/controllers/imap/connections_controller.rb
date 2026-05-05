# frozen_string_literal: true

module Imap
  class ConnectionsController < AccountScopedController
    include MailConnections

    private

    def connections_scope
      @account.imap_connections
    end

    def connection_params
      params.require(:imap_connection).permit(
        :host, :port, :ssl, :username, :password, :inbox_folder, :active
      )
    end

    def connection_json(connection)
      {
        id: connection.id,
        host: connection.host,
        port: connection.port,
        ssl: connection.ssl,
        username: connection.username,
        inbox_folder: connection.inbox_folder,
        last_synced_uid: connection.last_synced_uid,
        active: connection.active,
        created_at: connection.created_at,
        updated_at: connection.updated_at
      }
    end
  end
end
