# frozen_string_literal: true

module AgentMailbox
  class ConnectionSyncsController < ApplicationController
    def create
      account = Account.find(params[:account_id])
      connection = account.agentmail_connections.find(params[:connection_id])
      SyncAgentMailboxJob.perform_later(connection.id)

      render json: {
        status: "enqueued",
        account_id: account.id,
        agentmail_connection_id: connection.id
      }, status: :accepted
    rescue ActiveRecord::RecordNotFound => e
      render json: {error: e.message}, status: :not_found
    end
  end
end
