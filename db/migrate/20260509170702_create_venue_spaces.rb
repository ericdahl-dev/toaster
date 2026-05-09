class CreateVenueSpaces < ActiveRecord::Migration[8.1]
  def change
    create_table :venue_spaces do |t|
      t.references :venue, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :min_guests
      t.integer :capacity_seated
      t.integer :capacity_reception
      t.integer :pricing_floor_cents

      t.timestamps
    end
  end
end
