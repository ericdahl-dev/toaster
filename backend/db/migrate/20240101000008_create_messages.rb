class CreateMessages < ActiveRecord::Migration[7.2]
  def change
    create_table :messages do |t|
      t.references :account, null: false, foreign_key: true
      t.references :conversation_thread, null: false, foreign_key: true
      t.references :booking_request, foreign_key: true
      t.string :direction, null: false
      t.string :gmail_message_id
      t.text :body_text
      t.text :body_html
      t.datetime :sent_at
      t.timestamps
    end
    add_index :messages, :direction
  end
end
