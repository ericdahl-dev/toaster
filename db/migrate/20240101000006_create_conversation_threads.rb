class CreateConversationThreads < ActiveRecord::Migration[7.2]
  def change
    create_table :conversation_threads do |t|
      t.references :account, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true
      t.string :gmail_thread_id, null: false
      t.string :subject
      t.timestamps
    end
    add_index :conversation_threads, [:account_id, :gmail_thread_id], unique: true
  end
end
