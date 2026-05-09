class CreateTasks < ActiveRecord::Migration[7.2]
  def change
    create_table :tasks do |t|
      t.references :account, null: false, foreign_key: true
      t.references :booking_request, null: false, foreign_key: true
      t.string :title, null: false
      t.string :status, null: false, default: "open"
      t.datetime :due_at
      t.timestamps
    end
    add_index :tasks, :status
  end
end
