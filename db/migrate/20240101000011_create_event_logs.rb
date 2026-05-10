class CreateEventLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :event_logs do |t|
      t.references :account, null: false, foreign_key: true
      t.string :event_type, null: false
      t.string :subject_type
      t.bigint :subject_id
      t.jsonb :payload, null: false, default: {}
      t.timestamps
    end
    add_index :event_logs, :event_type
    add_index :event_logs, [ :subject_type, :subject_id ]
  end
end
