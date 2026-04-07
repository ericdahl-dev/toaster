module Gmail
  class OauthController < ApplicationController
    def start
      account = Account.find(params.require(:account_id))
      state = encode_state(account_id: account.id)
      auth_url = GmailOauthService.new.authorization_url(state: state)
      render json: {auth_url: auth_url}
    rescue ActiveRecord::RecordNotFound
      render json: {error: "Account not found"}, status: :not_found
    end

    def callback
      code = params.require(:code)
      state = decode_state(params.require(:state))
      account = Account.find(state[:account_id])

      oauth_service = GmailOauthService.new
      token_data = oauth_service.exchange_code(code)
      email = oauth_service.fetch_user_email(token_data["access_token"])

      connection = GmailConnection.find_or_initialize_by(account: account, email: email)
      connection.update!(
        access_token: token_data["access_token"],
        refresh_token: token_data["refresh_token"] || connection.refresh_token,
        token_expires_at: Time.current + token_data["expires_in"].to_i.seconds,
        active: true,
        user: connection.user || account.users.first
      )

      render json: {connection: connection_json(connection)}
    rescue ActionController::ParameterMissing => e
      render json: {error: e.message}, status: :bad_request
    rescue ActiveRecord::RecordNotFound
      render json: {error: "Account not found"}, status: :not_found
    rescue GmailOauthService::Error => e
      render json: {error: e.message}, status: :unprocessable_entity
    end

    private

    def encode_state(data)
      Base64.strict_encode64(data.to_json)
    end

    def decode_state(state)
      JSON.parse(Base64.strict_decode64(state), symbolize_names: true)
    rescue JSON::ParserError, ArgumentError
      raise ActionController::ParameterMissing, "state"
    end

    def connection_json(connection)
      {
        id: connection.id,
        email: connection.email,
        active: connection.active,
        token_expires_at: connection.token_expires_at,
        watch_expiration: connection.watch_expiration,
        watch_active: connection.watch_active?,
        healthy: connection.healthy?
      }
    end
  end
end
