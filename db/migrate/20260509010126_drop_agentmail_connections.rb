class DropAgentmailConnections < ActiveRecord::Migration[7.2]
  def up
    drop_table :agentmail_connections
  end

  def down
    create_table :agentmail_connections do |t|
      t.bigint :account_id, null: false
      t.string :inbox_id, null: false
      t.string :api_key, null: false
      t.boolean :active, null: false, default: true
      t.datetime :last_synced_at
      t.timestamps
    end
    add_index :agentmail_connections, :account_id
    add_index :agentmail_connections, [:account_id, :inbox_id], unique: true
    add_foreign_key :agentmail_connections, :accounts
  end
end
