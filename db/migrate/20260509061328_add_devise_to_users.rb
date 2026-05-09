# frozen_string_literal: true

# Migrates the hand-rolled auth columns to Devise's expected schema.
#
# password_digest → encrypted_password  (same bcrypt format; Devise calls the column encrypted_password)
# remember_token_digest removed          (Devise uses remember_created_at + signed cookie)
# Adds reset_password_token + sent_at    (recoverable — password resets)
# Adds remember_created_at              (rememberable)
class AddDeviseToUsers < ActiveRecord::Migration[8.1]
  def up
    rename_column :users, :password_digest, :encrypted_password

    change_table :users do |t|
      t.string :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at
    end

    add_index :users, :reset_password_token, unique: true

    remove_column :users, :remember_token_digest, :string
  end

  def down
    rename_column :users, :encrypted_password, :password_digest

    remove_index :users, :reset_password_token
    remove_column :users, :reset_password_token
    remove_column :users, :reset_password_sent_at
    remove_column :users, :remember_created_at

    add_column :users, :remember_token_digest, :string
  end
end
