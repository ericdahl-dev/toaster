class DropSolidQueueTables < ActiveRecord::Migration[7.2]
  def up
    # Drop FK-dependent child tables before parent solid_queue_jobs
    drop_table :solid_queue_blocked_executions, if_exists: true
    drop_table :solid_queue_claimed_executions, if_exists: true
    drop_table :solid_queue_failed_executions, if_exists: true
    drop_table :solid_queue_ready_executions, if_exists: true
    drop_table :solid_queue_recurring_executions, if_exists: true
    drop_table :solid_queue_scheduled_executions, if_exists: true
    # Now safe to drop parent and remaining tables
    drop_table :solid_queue_jobs, if_exists: true
    drop_table :solid_queue_pauses, if_exists: true
    drop_table :solid_queue_processes, if_exists: true
    drop_table :solid_queue_recurring_tasks, if_exists: true
    drop_table :solid_queue_semaphores, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
