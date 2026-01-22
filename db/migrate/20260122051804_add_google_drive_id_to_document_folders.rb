class AddGoogleDriveIdToDocumentFolders < ActiveRecord::Migration[8.1]
  def change
    add_column :document_folders, :google_drive_id, :string
    add_index :document_folders, [ :community_id, :google_drive_id ], unique: true, where: "google_drive_id IS NOT NULL"
  end
end
