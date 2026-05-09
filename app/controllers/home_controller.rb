class HomeController < ApplicationController
  def index
    redirect_to booking_requests_path if current_user
  end
end
