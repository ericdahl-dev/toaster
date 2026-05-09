# frozen_string_literal: true

class Admin::BaseController < ApplicationController
  before_action :require_authenticated_html_user!
  before_action :require_admin!

  private

  def require_admin!
    unless current_user&.admin?
      redirect_to root_path, alert: "You are not authorized to perform that action."
    end
  end
end
