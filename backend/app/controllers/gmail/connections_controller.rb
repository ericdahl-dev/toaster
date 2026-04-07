module Gmail
  class ConnectionsController < ApplicationController
    before_action :set_account
    before_action :set_connection, only: [:show, :reconnect, :resync]

    def index
      connections = @account.gmail_connections.order(:created_at)
      render json: {connections: connections.map { |c| connection_json(c) }}
    end

    def show
      render json: {connection: connection_json(@connection)}
    end

    def reconnect
      state = encode_state(account_id: @account.id, connection_id: @connection.id)
      auth_url = GmailOauthService.new.authorization_url(state: state)
      render json: {auth_url: auth_url}
    end

    def resync
      GmailWatchService.new(@connection).renew
      render json: {connection: connection_json(@connection.reload)}
    rescue GmailWatchService::Error => e
      render json: {error: e.message}, status: :unprocessable_entity
    end

    private

    def set_account
      @account = Account.find(params[:account_id])
    rescue ActiveRecord::RecordNotFound
      render json: {error: "Account not found"}, status: :not_found
    end

    def set_connection
      @connection = @account.gmail_connections.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: {error: "Connection not found"}, status: :not_found
    end

    def encode_state(data)
      Base64.strict_encode64(data.to_json)
    end

    def connection_json(connection)
      {
        id: connection.id,
        email: connection.email,
        active: connection.active,
        token_expires_at: connection.token_expires_at,
        watch_expiration: connection.watch_expiration,
        watch_active: connection.watch_active?,
        watch_expires_soon: connection.watch_expires_soon?,
        healthy: connection.healthy?
      }
    end
  end
end
