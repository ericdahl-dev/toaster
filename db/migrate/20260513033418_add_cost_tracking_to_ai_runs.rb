class AddCostTrackingToAiRuns < ActiveRecord::Migration[8.1]
  NEW_RUN_TYPES = %w[classifier extraction draft_writer embedding unstructured].freeze

  def up
    add_column :ai_runs, :page_count, :integer
    add_column :ai_runs, :estimated_cost_cents, :integer

    remove_check_constraint :ai_runs, name: "ai_runs_run_type_check"
    add_check_constraint :ai_runs,
      "run_type::text = ANY (ARRAY[#{NEW_RUN_TYPES.map { |t| "'#{t}'::character varying::text" }.join(", ")}])",
      name: "ai_runs_run_type_check"
  end

  def down
    remove_column :ai_runs, :page_count
    remove_column :ai_runs, :estimated_cost_cents

    remove_check_constraint :ai_runs, name: "ai_runs_run_type_check"
    add_check_constraint :ai_runs,
      "run_type::text = ANY (ARRAY['classifier'::character varying::text, 'extraction'::character varying::text, 'draft_writer'::character varying::text])",
      name: "ai_runs_run_type_check"
  end
end
