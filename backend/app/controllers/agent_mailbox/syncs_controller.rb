module AgentMailbox
  class SyncsController < ApplicationController
    before_action :set_account

    def create
      connections = @account.agentmail_connections.active_connections
      connections.each { |conn| SyncAgentMailboxJob.perform_later(conn.id) }

      render json: {
        status: "enqueued",
        account_id: @account.id,
        connection_count: connections.size
      }, status: :accepted
    end

    private

    def set_account
      @account = Account.find(params[:account_id])
    rescue ActiveRecord::RecordNotFound
      render json: {error: "Account not found"}, status: :not_found
    end
  end
end
