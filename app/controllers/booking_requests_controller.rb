# frozen_string_literal: true

class BookingRequestsController < ApplicationController
  before_action :require_authenticated_html_user!
  before_action :set_booking_request, only: [:show, :transition]

  def index
    @booking_requests = current_user.account.booking_requests.order(created_at: :desc)
  end

  def show
  end

  def transition
    to = params[:to].to_s
    BookingRequests::Transition.call(booking_request: @booking_request, to: to, metadata: {distinct_id: current_user.posthog_distinct_id})
    redirect_to booking_request_path(@booking_request), notice: "Status updated to #{to}."
  rescue BookingRequests::Transition::InvalidTransition => e
    redirect_to booking_request_path(@booking_request), alert: e.message
  end

  private

  def set_booking_request
    @booking_request = current_user.account.booking_requests
      .includes(:source_inbox_message)
      .find_by(id: params[:id])
    render plain: "Not Found", status: :not_found unless @booking_request
  end
end
