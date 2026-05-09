# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Authentication

  protect_from_forgery with: :exception

  helper_method :current_user
end
