# frozen_string_literal: true

class BookingRequestsController < ApplicationController
  before_action :require_authenticated_html_user!
  before_action :set_booking_request, only: :show

  def index
    @booking_requests = current_user.account.booking_requests.order(created_at: :desc)
  end

  def show
  end

  private

  def set_booking_request
    @booking_request = current_user.account.booking_requests.find_by(id: params[:id])
    render plain: "Not Found", status: :not_found unless @booking_request
  end
end
