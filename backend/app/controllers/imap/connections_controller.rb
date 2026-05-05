module Imap
  class ConnectionsController < AccountScopedController
    before_action :set_connection, only: [:show, :update, :destroy]

    def index
      connections = @account.imap_connections.order(:created_at)
      render json: {connections: connections.map { |c| connection_json(c) }}
    end

    def show
      render json: {connection: connection_json(@connection)}
    end

    def create
      connection = @account.imap_connections.build(connection_params)
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
      @connection = @account.imap_connections.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: {error: "Connection not found"}, status: :not_found
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
