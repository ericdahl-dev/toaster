# frozen_string_literal: true

module Auth
  class SessionsController < ApplicationController
    skip_forgery_protection

    before_action :require_authenticated_user!, only: [:me]

    def create
      creds = login_credentials
      email = creds[:email].to_s.strip.downcase
      user = User.find_by(email: email)
      if user&.authenticate(creds[:password].to_s)
        session[:user_id] = user.id
        head :ok
      else
        render json: {error: "Unauthorized"}, status: :unauthorized
      end
    end

    def destroy
      reset_session
      head :no_content
    end

    def me
      render json: {
        id: current_user.id,
        email: current_user.email,
        account: {id: current_user.account_id, name: current_user.account.name}
      }
    end

    private

    def login_credentials
      p = params.permit(:email, :password, session: %i[email password])
      nested = p[:session]
      email = p[:email].presence || nested&.dig(:email) || nested&.dig("email")
      password = p[:password].presence || nested&.dig(:password) || nested&.dig("password")
      {email:, password:}
    end
  end
end
