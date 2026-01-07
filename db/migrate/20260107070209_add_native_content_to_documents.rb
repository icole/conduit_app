class AddNativeContentToDocuments < ActiveRecord::Migration[8.1]
  def change
    unless column_exists?(:documents, :storage_type)
      add_column :documents, :storage_type, :integer, default: 0, null: false
    end
    unless column_exists?(:documents, :content)
      add_column :documents, :content, :text
    end

    # Mark existing documents with Google Drive URLs as google_drive type
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE documents
          SET storage_type = 1
          WHERE google_drive_url IS NOT NULL AND google_drive_url != '' AND storage_type = 0
        SQL
      end
    end
  end
end
