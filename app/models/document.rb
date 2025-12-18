class Document < ApplicationRecord
  acts_as_tenant :community

  has_and_belongs_to_many :calendar_events
  has_many :decisions, dependent: :nullify

  validates :google_drive_url, presence: true, format: {
    with: /\Ahttps:\/\/(?:docs|drive)\.google\.com\/.*\z/,
    message: "must be a valid Google Drive URL"
  }

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
end
