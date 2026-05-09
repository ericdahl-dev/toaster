class CreateVenueChunks < ActiveRecord::Migration[8.1]
  def change
    create_table :venue_chunks do |t|
      t.references :venue_document, null: false, foreign_key: true
      t.text :content, null: false
      t.vector :embedding, limit: 3072

      t.timestamps
    end
  end
end
