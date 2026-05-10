# frozen_string_literal: true

class AddPasswordDigestAndUniqueEmailToUsers < ActiveRecord::Migration[7.2]
  def up
    add_column :users, :password_digest, :string
    User.reset_column_information
    remove_index :users, name: "index_users_on_account_id_and_email"
    add_index :users, :email, unique: true
    User.find_each do |user|
      user.update_column(:password_digest, BCrypt::Password.create(SecureRandom.hex(24)))
    end
    change_column_null :users, :password_digest, false
  end

  def down
    change_column_null :users, :password_digest, true
    remove_index :users, :email
    add_index :users, [ :account_id, :email ], unique: true, name: "index_users_on_account_id_and_email"
    remove_column :users, :password_digest
  end
end
