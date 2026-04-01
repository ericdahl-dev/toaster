class RenameModelNameInAiRuns < ActiveRecord::Migration[7.2]
  def change
    rename_column :ai_runs, :model_name, :llm_model
  end
end
