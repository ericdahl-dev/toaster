# frozen_string_literal: true

module Auth
  class SessionsController < ApplicationController
    skip_forgery_protection

    before_action :require_authenticated_user!, only: [:me]

    def create
      email = login_params[:email].to_s.strip.downcase
      user = User.find_by(email: email)
      if user&.authenticate(login_params[:password].to_s)
        session[:user_id] = user.id
        if login_params[:remember_me].in?(["1", "true", true])
          raw_token = user.remember
          cookies.signed[:remember_token] = {
            value: "#{user.id}:#{raw_token}",
            expires: 30.days,
            httponly: true,
            same_site: :lax
          }
        end
        head :ok
      else
        render json: { error: "Unauthorized" }, status: :unauthorized
      end
    end

    def destroy
      current_user&.forget
      cookies.delete(:remember_token)
      reset_session
      head :no_content
    end

    def me
      render json: {
        id: current_user.id,
        email: current_user.email,
        account: { id: current_user.account_id, name: current_user.account.name }
      }
    end

    private

    def login_params
      params.permit(:email, :password, :remember_me)
    end
  end
end
