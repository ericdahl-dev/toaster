# frozen_string_literal: true

module Authentication
  extend ActiveSupport::Concern

  private

  def current_user
    return @current_user if defined?(@current_user)

    @current_user =
      if session[:user_id].present?
        User.find_by(id: session[:user_id])
      else
        user_from_remember_cookie
      end
  end

  def require_authenticated_user!
    return if current_user

    render json: { error: "Unauthorized" }, status: :unauthorized
  end

  def user_from_remember_cookie
    cookie_value = cookies.signed[:remember_token]
    return nil if cookie_value.blank?

    user_id, raw_token = cookie_value.to_s.split(":", 2)
    return nil if user_id.blank? || raw_token.blank?

    user = User.find_by(id: user_id.to_i)
    return nil unless user&.authenticated_by_token?(raw_token)

    # Restore the short-lived session so subsequent requests are cheaper.
    session[:user_id] = user.id
    user
  end
end
