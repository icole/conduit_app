class CreateDocumentFolders < ActiveRecord::Migration[8.1]
  def change
    create_table :document_folders do |t|
      t.string :name, null: false
      t.bigint :parent_id, index: true
      t.references :community, null: false, foreign_key: true, index: true
      t.references :created_by, foreign_key: { to_table: :users }, index: true

      t.timestamps
    end

    add_foreign_key :document_folders, :document_folders, column: :parent_id

    # Add folder reference to documents
    add_reference :documents, :document_folder, foreign_key: true, index: true
  end
end
