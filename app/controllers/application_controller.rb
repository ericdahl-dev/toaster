# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Authentication

  protect_from_forgery with: :exception

  helper_method :current_account, :current_user

  private

  def current_account
    current_user&.account
  end
end
