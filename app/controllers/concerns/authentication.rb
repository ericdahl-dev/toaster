# frozen_string_literal: true

# Thin wrappers that preserve the existing controller API while delegating to Devise.
# Controllers call require_authenticated_html_user! exactly as before.
module Authentication
  extend ActiveSupport::Concern

  private

  def require_authenticated_user!
    return if current_user

    render json: { error: "Unauthorized" }, status: :unauthorized
  end

  def require_authenticated_html_user!
    authenticate_user!
  end
end
