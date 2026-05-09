# frozen_string_literal: true

class SessionsController < Devise::SessionsController
  layout "application"

  def new
    redirect_to root_path, notice: "Already signed in." if current_user
    super
  end

  protected

  def after_sign_in_path_for(_resource)
    root_path
  end

  def after_sign_out_path_for(_resource_or_scope)
    login_path
  end
end
