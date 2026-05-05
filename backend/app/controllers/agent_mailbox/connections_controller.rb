# frozen_string_literal: true

module AgentMailbox
  class ConnectionsController < AccountScopedController
    before_action :set_connection, only: [:show, :update, :destroy]

    def index
      connections = @account.agentmail_connections.order(:created_at)
      render json: {connections: connections.map { |c| connection_json(c) }}
    end

    def show
      render json: {connection: connection_json(@connection)}
    end

    def create
      connection = @account.agentmail_connections.build(connection_params)
      if connection.save
        InboxSyncScheduler.schedule(connection)
        render json: {connection: connection_json(connection)}, status: :created
      else
        render json: {errors: connection.errors.full_messages}, status: :unprocessable_entity
      end
    end

    def update
      if @connection.update(connection_params)
        render json: {connection: connection_json(@connection)}
      else
        render json: {errors: @connection.errors.full_messages}, status: :unprocessable_entity
      end
    end

    def destroy
      @connection.destroy
      head :no_content
    end

    private

    def set_connection
      @connection = @account.agentmail_connections.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: {error: "Connection not found"}, status: :not_found
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
