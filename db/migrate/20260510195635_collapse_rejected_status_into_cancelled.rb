class CollapseRejectedStatusIntoCancelled < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE booking_requests SET status = 'cancelled' WHERE status = 'rejected'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
