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
        if remember_me?(creds)
          raw = user.issue_remember_token!
          write_remember_cookie(user.id, raw)
        else
          user.clear_remember_token!
          delete_remember_cookie
        end
        head :ok
      else
        render json: {error: "Unauthorized"}, status: :unauthorized
      end
    end

    def destroy
      u = current_user
      reset_session
      u&.clear_remember_token!
      delete_remember_cookie
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
      p = params.permit(:email, :password, :remember_me, session: %i[email password remember_me])
      nested = p[:session]
      email = p[:email].presence || nested&.dig(:email) || nested&.dig("email")
      password = p[:password].presence || nested&.dig(:password) || nested&.dig("password")
      remember_me = p.key?(:remember_me) ? p[:remember_me] : nested&.dig(:remember_me) || nested&.dig("remember_me")
      {email:, password:, remember_me:}
    end

    def remember_me?(creds)
      ActiveModel::Type::Boolean.new.cast(creds[:remember_me])
    end
  end
end
