class CreateVenues < ActiveRecord::Migration[7.2]
  def change
    create_table :venues do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :address
      t.integer :capacity
      t.timestamps
    end
  end
end
