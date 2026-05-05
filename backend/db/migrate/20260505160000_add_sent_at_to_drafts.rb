# frozen_string_literal: true

class AddSentAtToDrafts < ActiveRecord::Migration[7.2]
  def up
    add_column :drafts, :sent_at, :datetime
    execute <<~SQL.squish
      UPDATE drafts SET sent_at = updated_at WHERE status = 'sent'
    SQL
  end

  def down
    remove_column :drafts, :sent_at
  end
end
