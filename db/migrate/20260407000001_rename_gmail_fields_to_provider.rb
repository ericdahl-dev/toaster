class RenameGmailFieldsToProvider < ActiveRecord::Migration[7.2]
  def change
    rename_column :conversation_threads, :gmail_thread_id, :provider_thread_id
    rename_column :messages, :gmail_message_id, :provider_message_id

    execute <<~SQL
      ALTER INDEX IF EXISTS "index_conversation_threads_on_account_id_and_gmail_thread_id"
        RENAME TO "index_conversation_threads_on_account_id_and_provider_thread_id"
    SQL

    execute <<~SQL
      ALTER INDEX IF EXISTS "index_messages_on_account_id_and_gmail_message_id"
        RENAME TO "index_messages_on_account_id_and_provider_message_id"
    SQL
  end
end
