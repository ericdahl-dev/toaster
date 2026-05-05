# frozen_string_literal: true

class VenuesController < AccountScopedController
  before_action :set_venue, only: [ :show, :update, :destroy ]

  def index
    venues = @account.venues.order(:name)
    render json: { venues: venues.map { |v| venue_json(v) } }
  end

  def show
    render json: { venue: venue_json(@venue) }
  end

  def create
    venue = @account.venues.build(venue_params)
    if venue.save
      render json: { venue: venue_json(venue) }, status: :created
    else
      render json: { errors: venue.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @venue.update(venue_params)
      render json: { venue: venue_json(@venue) }
    else
      render json: { errors: @venue.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @venue.destroy
    head :no_content
  end

  private

  def set_venue
    @venue = @account.venues.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Venue not found" }, status: :not_found
  end

  def venue_params
    params.require(:venue).permit(:name, :address, :capacity)
  end

  def venue_json(venue)
    {
      id: venue.id,
      name: venue.name,
      address: venue.address,
      capacity: venue.capacity,
      created_at: venue.created_at,
      updated_at: venue.updated_at
    }
  end
end
