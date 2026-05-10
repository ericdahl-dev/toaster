class AddRagChunkCountToAiRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :ai_runs, :rag_chunk_count, :integer, default: 0, null: false
  end
end
