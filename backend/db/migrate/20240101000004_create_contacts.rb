class CreateContacts < ActiveRecord::Migration[7.2]
  def change
    create_table :contacts do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.citext :email
      t.string :phone
      t.timestamps
    end
    add_index :contacts, [:account_id, :email]
  end
end
