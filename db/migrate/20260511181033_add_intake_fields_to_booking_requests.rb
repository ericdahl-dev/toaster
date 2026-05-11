# frozen_string_literal: true

class AddIntakeFieldsToBookingRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :booking_requests, :feature_preferences, :jsonb, default: [], null: false
    add_column :booking_requests, :recommended_venue_space_id, :bigint

    add_index :booking_requests, :recommended_venue_space_id
    add_foreign_key :booking_requests, :venue_spaces, column: :recommended_venue_space_id
  end
end
