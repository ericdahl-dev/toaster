class AddWatchFieldsToGmailConnections < ActiveRecord::Migration[7.2]
  def change
    add_column :gmail_connections, :watch_resource_id, :string
    add_column :gmail_connections, :watch_history_id, :string
    add_column :gmail_connections, :watch_expiration, :datetime
  end
end
