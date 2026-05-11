# frozen_string_literal: true

class AddIntakeFieldsToVenueSpacesAndVenues < ActiveRecord::Migration[8.1]
  def change
    add_column :venue_spaces, :duration_options, :jsonb, default: [], null: false
    add_column :venue_spaces, :private, :boolean, default: false, null: false
    add_column :venue_spaces, :max_guests, :integer
    add_column :venue_spaces, :features, :jsonb, default: [], null: false

    add_column :venues, :features, :jsonb, default: [], null: false
  end
end
