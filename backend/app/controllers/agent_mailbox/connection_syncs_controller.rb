# frozen_string_literal: true

module AgentMailbox
  class ConnectionSyncsController < AccountScopedController
    include MailConnectionSync

    private

    def connections_scope
      @account.agentmail_connections
    end

    def connection_id_key
      :agentmail_connection_id
    end
  end
end
