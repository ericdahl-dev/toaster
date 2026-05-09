class AddImapDraftFieldsToDrafts < ActiveRecord::Migration[7.2]
  def change
    add_column :drafts, :imap_draft_uid, :integer
    add_column :drafts, :original_body, :text
  end
end
