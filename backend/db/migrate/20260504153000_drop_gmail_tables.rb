class DropGmailTables < ActiveRecord::Migration[7.2]
  def change
    drop_table :gmail_connections, if_exists: true
    drop_table :gmail_webhook_events, if_exists: true
  end
end
