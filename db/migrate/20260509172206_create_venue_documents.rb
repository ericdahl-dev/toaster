class CreateVenueDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :venue_documents do |t|
      t.references :venue, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.string :source_filename, null: false
      t.integer :chunk_count
      t.text :error_message

      t.timestamps
    end
  end
end
