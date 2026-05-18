class AddBackfillTrackingToImapConnections < ActiveRecord::Migration[8.1]
  def change
    add_column :imap_connections, :last_backfill_at, :datetime
    add_column :imap_connections, :last_backfill_days, :integer
  end
end
