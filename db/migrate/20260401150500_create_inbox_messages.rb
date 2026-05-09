class CreateInboxMessages < ActiveRecord::Migration[7.2]
  def change
    create_table :inbox_messages do |t|
      t.references :account, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :provider_message_id, null: false
      t.string :provider_thread_id
      t.string :direction, null: false, default: "inbound"
      t.string :from_name
      t.string :from_email
      t.jsonb :to_emails, null: false, default: []
      t.string :subject
      t.text :body_text
      t.text :body_html
      t.datetime :received_at
      t.jsonb :raw_payload, null: false, default: {}

      t.timestamps
    end

    add_index :inbox_messages, [:account_id, :provider, :provider_message_id], unique: true, name: "idx_inbox_messages_unique_provider_message"
    add_index :inbox_messages, [:account_id, :provider_thread_id], name: "idx_inbox_messages_on_account_and_thread"
    add_index :inbox_messages, :direction
  end
end
