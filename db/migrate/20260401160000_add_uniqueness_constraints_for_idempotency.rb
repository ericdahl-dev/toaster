class AddUniquenessConstraintsForIdempotency < ActiveRecord::Migration[7.2]
  def change
    # Upgrade the existing non-unique contacts index to a unique partial index
    # (partial so multiple contacts with NULL email are still allowed per account)
    remove_index :contacts, name: "index_contacts_on_account_id_and_email"
    add_index :contacts, %i[account_id email], unique: true,
      where: "email IS NOT NULL",
      name: "index_contacts_on_account_id_and_email"

    # Add a unique partial index on messages so concurrent workers cannot
    # insert duplicate Message rows for the same Gmail message id
    add_index :messages, %i[account_id gmail_message_id], unique: true,
      where: "gmail_message_id IS NOT NULL",
      name: "index_messages_on_account_id_and_gmail_message_id"
  end
end
