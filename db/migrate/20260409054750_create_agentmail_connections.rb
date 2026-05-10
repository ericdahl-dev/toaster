class CreateAgentmailConnections < ActiveRecord::Migration[7.2]
  def change
    create_table :agentmail_connections do |t|
      t.references :account, null: false, foreign_key: true
      t.string :inbox_id, null: false
      t.text :api_key, null: false
      t.boolean :active, null: false, default: true
      t.datetime :last_synced_at

      t.timestamps
    end

    add_index :agentmail_connections, [ :account_id, :inbox_id ], unique: true
  end
end
