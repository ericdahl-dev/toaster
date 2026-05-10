class RenameBudgetCentsTobudgetOnBookingRequests < ActiveRecord::Migration[8.1]
  def change
    rename_column :booking_requests, :budget_cents, :budget
    change_column :booking_requests, :budget, :decimal, precision: 10, scale: 2
  end
end
