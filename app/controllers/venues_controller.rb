# frozen_string_literal: true

class VenuesController < ApplicationController
  before_action :require_authenticated_html_user!
  before_action :set_venue, only: [ :edit, :update, :destroy ]

  def index
    @venues = current_user.account.venues.order(:name)
  end

  def new
    @venue = current_user.account.venues.build
  end

  def create
    @venue = current_user.account.venues.build(venue_params)
    if @venue.save
      Telemetry.capture(distinct_id: current_user.posthog_distinct_id, event: "venue_created", properties: { venue_id: @venue.id, venue_name: @venue.name })
      if params[:onboarding]
        redirect_to onboarding_mail_connection_path, notice: "Venue created."
      else
        redirect_to venues_path, notice: "Venue created."
      end
    elsif params[:onboarding]
      render "onboarding/venue", status: :unprocessable_content
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @venue.update(venue_params)
      redirect_to venues_path, notice: "Venue updated."
    else
      render :edit, status: :unprocessable_content
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
    raw = params.require(:venue).permit(
      :name, :address, :capacity, :features,
      venue_spaces_attributes: [
        :id, :name, :min_guests, :max_guests, :capacity_seated, :capacity_reception,
        :pricing_floor_cents, :private, :duration_options, :features, :_destroy
      ]
    )

    raw[:features] = normalize_csv(raw[:features]) if raw.key?(:features)

    raw[:venue_spaces_attributes]&.each do |attrs|
      attrs[:duration_options] = normalize_csv(attrs[:duration_options]) if attrs.key?(:duration_options)
      attrs[:features] = normalize_csv(attrs[:features]) if attrs.key?(:features)
    end

    raw
  end

  def normalize_csv(value)
    return value if value.is_a?(Array)
    value.to_s.split(",").map(&:strip).reject(&:blank?)
  end
end
