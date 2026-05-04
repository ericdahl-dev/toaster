# frozen_string_literal: true

module Authentication
  extend ActiveSupport::Concern

  private

  def current_user
    return @current_user if defined?(@current_user)

    @current_user =
      if session[:user_id].present?
        User.find_by(id: session[:user_id])
      end
  end

  def require_authenticated_user!
    return if current_user

    render json: {error: "Unauthorized"}, status: :unauthorized
  end
end
