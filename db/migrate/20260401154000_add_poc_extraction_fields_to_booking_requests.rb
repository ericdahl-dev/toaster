class AddPocExtractionFieldsToBookingRequests < ActiveRecord::Migration[7.2]
  def change
    add_reference :booking_requests, :source_inbox_message, foreign_key: {to_table: :inbox_messages}, index: {unique: true}
    add_column :booking_requests, :extraction_snapshot, :jsonb, null: false, default: {}
    add_column :booking_requests, :missing_fields, :jsonb, null: false, default: []
    add_column :booking_requests, :review_reasons, :jsonb, null: false, default: []
  end
end
