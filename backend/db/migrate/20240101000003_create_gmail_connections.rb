class CreateGmailConnections < ActiveRecord::Migration[7.2]
  def change
    create_table :gmail_connections do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.citext :email, null: false
      t.text :access_token
      t.text :refresh_token
      t.datetime :token_expires_at
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :gmail_connections, [:account_id, :email], unique: true
  end
end
