class AddRunTypeAndLatencyToAiRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :ai_runs, :run_type, :string, null: false, default: "extraction"
    add_column :ai_runs, :prompt_version, :string
    add_column :ai_runs, :latency_ms, :integer
    add_check_constraint :ai_runs, "run_type IN ('classifier', 'extraction')", name: "ai_runs_run_type_check"
  end
end
