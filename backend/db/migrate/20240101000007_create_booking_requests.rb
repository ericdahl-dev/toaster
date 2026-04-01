class CreateBookingRequests < ActiveRecord::Migration[7.2]
  def change
    create_table :booking_requests do |t|
      t.references :account, null: false, foreign_key: true
      t.references :conversation_thread, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true
      t.references :venue, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.date :event_date
      t.date :event_end_date
      t.integer :headcount
      t.integer :budget_cents
      t.text :notes
      t.timestamps
    end
    add_index :booking_requests, :status
  end
end
