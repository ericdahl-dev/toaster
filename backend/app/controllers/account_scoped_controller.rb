# frozen_string_literal: true

class AccountScopedController < ApplicationController
  # JSON mutating requests do not send a CSRF token; :null_session would clear the session.
  skip_forgery_protection

  before_action :require_authenticated_user!
  before_action :require_matching_account_param!
  before_action :set_account

  private

  def require_matching_account_param!
    return if params[:account_id].blank?
    return if params[:account_id].to_i == current_user.account_id

    render json: {error: "Forbidden"}, status: :forbidden
  end

  def set_account
    @account = current_user.account
  end
end
