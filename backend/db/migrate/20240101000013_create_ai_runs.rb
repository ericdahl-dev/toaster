class CreateAiRuns < ActiveRecord::Migration[7.2]
  def change
    create_table :ai_runs do |t|
      t.references :account, null: false, foreign_key: true
      t.references :booking_request, foreign_key: true
      t.string :model_name, null: false
      t.text :prompt, null: false
      t.text :response
      t.integer :input_tokens
      t.integer :output_tokens
      t.timestamps
    end
  end
end
