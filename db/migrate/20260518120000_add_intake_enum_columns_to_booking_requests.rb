# frozen_string_literal: true

class AddIntakeEnumColumnsToBookingRequests < ActiveRecord::Migration[8.1]
  def up
    add_column :booking_requests, :booking_type, :string unless column_exists?(:booking_requests, :booking_type)
    add_column :booking_requests, :duration, :string unless column_exists?(:booking_requests, :duration)
    add_column :booking_requests, :private_space_preference, :string unless column_exists?(:booking_requests, :private_space_preference)
    add_column :booking_requests, :beverage_format, :string unless column_exists?(:booking_requests, :beverage_format)
    add_column :booking_requests, :lead_recap, :text unless column_exists?(:booking_requests, :lead_recap)
    add_column :booking_requests, :recommended_package, :string unless column_exists?(:booking_requests, :recommended_package)
  end

  def down
    remove_column :booking_requests, :recommended_package if column_exists?(:booking_requests, :recommended_package)
    remove_column :booking_requests, :lead_recap if column_exists?(:booking_requests, :lead_recap)
    remove_column :booking_requests, :beverage_format if column_exists?(:booking_requests, :beverage_format)
    remove_column :booking_requests, :private_space_preference if column_exists?(:booking_requests, :private_space_preference)
    remove_column :booking_requests, :duration if column_exists?(:booking_requests, :duration)
    remove_column :booking_requests, :booking_type if column_exists?(:booking_requests, :booking_type)
  end
end
