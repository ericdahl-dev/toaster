# frozen_string_literal: true

class AddArchivedAtToBookingRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :booking_requests, :archived_at, :datetime
    add_index :booking_requests, :archived_at
  end
end
