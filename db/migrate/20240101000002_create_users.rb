class CreateUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      t.references :account, null: false, foreign_key: true
      t.citext :email, null: false
      t.string :name, null: false
      t.timestamps
    end
    add_index :users, [:account_id, :email], unique: true
  end
end
