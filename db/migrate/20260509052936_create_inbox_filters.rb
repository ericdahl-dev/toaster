class CreateInboxFilters < ActiveRecord::Migration[8.1]
  def change
    create_table :inbox_filters do |t|
      t.references :imap_connection, null: false, foreign_key: true
      t.references :venue, null: false, foreign_key: true
      t.string :keyword, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end
  end
end
