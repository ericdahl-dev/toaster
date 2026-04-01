class CreateDrafts < ActiveRecord::Migration[7.2]
  def change
    create_table :drafts do |t|
      t.references :account, null: false, foreign_key: true
      t.references :booking_request, null: false, foreign_key: true
      t.text :body, null: false
      t.string :status, null: false, default: "pending_review"
      t.timestamps
    end
    add_index :drafts, :status
  end
end
