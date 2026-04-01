class CreateGmailWebhookEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :gmail_webhook_events do |t|
      t.references :account, null: false, foreign_key: true
      t.string :gmail_history_id
      t.jsonb :raw_payload, null: false, default: {}
      t.datetime :processed_at
      t.timestamps
    end
  end
end
