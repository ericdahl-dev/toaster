class AddDraftWriterToAiRunsRunType < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      ALTER TABLE ai_runs DROP CONSTRAINT ai_runs_run_type_check;
      ALTER TABLE ai_runs ADD CONSTRAINT ai_runs_run_type_check
        CHECK (run_type::text = ANY (ARRAY['classifier'::character varying::text, 'extraction'::character varying::text, 'draft_writer'::character varying::text]));
    SQL
  end

  def down
    execute <<~SQL
      ALTER TABLE ai_runs DROP CONSTRAINT ai_runs_run_type_check;
      ALTER TABLE ai_runs ADD CONSTRAINT ai_runs_run_type_check
        CHECK (run_type::text = ANY (ARRAY['classifier'::character varying::text, 'extraction'::character varying::text]));
    SQL
  end
end
