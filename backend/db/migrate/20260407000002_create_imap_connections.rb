class CreateImapConnections < ActiveRecord::Migration[7.2]
  def change
    create_table :imap_connections do |t|
      t.references :account, null: false, foreign_key: true
      t.string :host, null: false
      t.integer :port, null: false, default: 993
      t.boolean :ssl, null: false, default: true
      t.string :username, null: false
      t.text :password
      t.string :inbox_folder, null: false, default: "INBOX"
      t.integer :last_synced_uid
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :imap_connections, [ :account_id, :username, :host ], unique: true,
              name: "index_imap_connections_on_account_username_host"
  end
end
