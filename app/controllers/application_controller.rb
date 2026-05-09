# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization

  protect_from_forgery with: :exception

  helper_method :current_user

  rescue_from Pundit::NotAuthorizedError do
    redirect_to root_path, alert: "You are not authorized to perform that action."
  end
end
