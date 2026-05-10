class AddFieldsToBookingRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :booking_requests, :start_time, :string
    add_column :booking_requests, :celebration_type, :string
    add_column :booking_requests, :fit_status, :string
    add_column :booking_requests, :staff_summary, :text
  end
end
