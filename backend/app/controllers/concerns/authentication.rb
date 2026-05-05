# frozen_string_literal: true

module Authentication
  extend ActiveSupport::Concern

  REMEMBER_COOKIE = :toaster_remember

  private

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = user_from_session || user_from_remember_cookie
    @current_user
  end

  def user_from_session
    User.find_by(id: session[:user_id]) if session[:user_id].present?
  end

  def user_from_remember_cookie
    data = cookies.signed[REMEMBER_COOKIE]
    return unless data.is_a?(Hash)

    user_id = data["user_id"] || data[:user_id]
    token = data["token"] || data[:token]
    return unless user_id && token

    user = User.find_by(id: user_id)
    return unless user&.valid_remember_token?(token)

    session[:user_id] = user.id
    user
  end

  def write_remember_cookie(user_id, raw_token)
    cookies.signed[REMEMBER_COOKIE] = {
      value: {"user_id" => user_id, "token" => raw_token},
      expires: User::REMEMBER_DURATION.from_now,
      httponly: true,
      secure: Rails.env.production?,
      same_site: :lax
    }
  end

  def delete_remember_cookie
    cookies.delete(REMEMBER_COOKIE, same_site: :lax)
  end

  def require_authenticated_user!
    return if current_user

    render json: {error: "Unauthorized"}, status: :unauthorized
  end
end
