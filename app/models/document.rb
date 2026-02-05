class Document < ApplicationRecord
  include Discardable

  acts_as_tenant :community

  belongs_to :document_folder, optional: true

  has_and_belongs_to_many :calendar_events
  has_many :decisions, dependent: :nullify

  has_one_attached :file

  # Native content stored as HTML (synced via Liveblocks)
  # Using a text column instead of ActionText for Liveblocks compatibility

  # Document storage types
  enum :storage_type, { native: 0, google_drive: 1, uploaded: 2 }, default: :native

  # Google Drive URL validation (only when using Google Drive)
  validates :google_drive_url, format: {
    with: /\Ahttps:\/\/(?:docs|drive)\.google\.com\/.*\z/,
    message: "must be a valid Google Drive URL"
  }, allow_blank: true

  before_validation :set_document_type_from_file, if: -> { uploaded? && document_type.blank? && file.attached? }
  before_validation :set_default_document_type, if: -> { native? && document_type.blank? }

  # Ensure document has content source
  validate :has_content_or_link

  def self.document_type_from_mime(mime_type)
    case mime_type
    when "application/vnd.google-apps.document"
      "Document"
    when "application/vnd.google-apps.spreadsheet"
      "Spreadsheet"
    when "application/vnd.google-apps.presentation"
      "Presentation"
    when "application/pdf"
      "PDF"
    when "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
         "application/msword"
      "Word Document"
    when "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
         "application/vnd.ms-excel"
      "Excel Spreadsheet"
    when "application/vnd.openxmlformats-officedocument.presentationml.presentation",
         "application/vnd.ms-powerpoint"
      "PowerPoint"
    when /\Aimage\//
      "Image"
    else
      "File"
    end
  end

  # Returns a safe Google Drive URL for use in links
  def safe_google_drive_url
    return nil if google_drive_url.blank?

    # Ensure the URL matches our validation pattern
    if google_drive_url.match?(/\Ahttps:\/\/(?:docs|drive)\.google\.com\/.*\z/)
      google_drive_url
    else
      nil
    end
  end

  def native?
    storage_type == "native" || (google_drive_url.blank? && !google_drive? && !uploaded?)
  end

  def google_drive?
    storage_type == "google_drive" || google_drive_url.present?
  end

  def uploaded?
    storage_type == "uploaded"
  end

  # Extract the Google Drive file ID from the URL
  # Supports formats like:
  # - https://docs.google.com/document/d/FILE_ID/edit
  # - https://drive.google.com/file/d/FILE_ID/view
  # - https://docs.google.com/spreadsheets/d/FILE_ID/edit
  def google_drive_file_id
    return nil if google_drive_url.blank?

    # Match the file ID from various Google Drive URL formats
    match = google_drive_url.match(%r{/d/([a-zA-Z0-9_-]+)})
    match&.[](1)
  end

  private

  def set_document_type_from_file
    self.document_type = self.class.document_type_from_mime(file.content_type)
  end

  def set_default_document_type
    self.document_type = "Document"
  end

  def has_content_or_link
    if uploaded? && !file.attached?
      errors.add(:file, "must be attached for uploaded documents")
    elsif native? && content.blank? && !new_record?
      # Allow empty content for new native documents (will be filled via editor)
    elsif google_drive? && google_drive_url.blank?
      errors.add(:google_drive_url, "is required for Google Drive documents")
    end
  end
end
