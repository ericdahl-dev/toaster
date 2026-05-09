class AddFilePathToVenueDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :venue_documents, :file_path, :string
  end
end
