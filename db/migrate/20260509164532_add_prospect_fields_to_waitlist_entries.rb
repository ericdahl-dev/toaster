class AddProspectFieldsToWaitlistEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :waitlist_entries, :full_name, :string, null: false, default: ""
    add_column :waitlist_entries, :company_name, :string, null: false, default: ""
    add_column :waitlist_entries, :status, :string, null: false, default: "pending"
    add_column :waitlist_entries, :invited_at, :datetime
  end
end
