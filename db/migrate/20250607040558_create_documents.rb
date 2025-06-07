class CreateDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :documents do |t|
      t.string :title
      t.text :description
      t.string :google_drive_url
      t.string :document_type

      t.timestamps
    end
  end
end
