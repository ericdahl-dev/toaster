# frozen_string_literal: true

class VenuesController < ApplicationController
  before_action :require_authenticated_html_user!
  before_action :set_venue, only: [:edit, :update, :destroy]

  def index
    @venues = current_user.account.venues.order(:name)
  end

  def new
    @venue = current_user.account.venues.build
  end

  def create
    @venue = current_user.account.venues.build(venue_params)
    if @venue.save
      redirect_to venues_path, notice: "Venue created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @venue.update(venue_params)
      redirect_to venues_path, notice: "Venue updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @venue.booking_requests.exists?
      redirect_to venues_path, alert: "Cannot delete #{@venue.name} — it has booking requests. Reassign them first."
      return
    end

    @venue.destroy!
    redirect_to venues_path, notice: "Venue deleted."
  end

  private

  def set_venue
    @venue = current_user.account.venues.find_by(id: params[:id])
    render plain: "Not Found", status: :not_found unless @venue
  end

  def venue_params
    params.require(:venue).permit(:name)
  end
end
