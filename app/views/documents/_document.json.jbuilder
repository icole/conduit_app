json.extract! document, :id, :title, :description, :google_drive_url, :document_type, :created_at, :updated_at
json.url document_url(document, format: :json)
