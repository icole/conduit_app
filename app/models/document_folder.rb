class DocumentFolder < ApplicationRecord
  acts_as_tenant :community

  belongs_to :community
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :parent, class_name: "DocumentFolder", optional: true

  has_many :children, class_name: "DocumentFolder", foreign_key: "parent_id", dependent: :destroy
  has_many :documents, dependent: :nullify

  validates :name, presence: true
  validates :name, uniqueness: { scope: [ :parent_id, :community_id ] }

  scope :synced_from_drive, -> { where.not(google_drive_id: nil) }
  scope :by_google_drive_id, ->(drive_id) { find_by(google_drive_id: drive_id) }

  # Returns true if this folder was synced from Google Drive
  def synced_from_drive?
    google_drive_id.present?
  end

  # Returns all folders in depth-first tree order (roots alphabetically, then children)
  def self.tree_ordered
    folders = all.order(:name).to_a
    by_parent = folders.group_by(&:parent_id)
    result = []
    build = ->(parent_id) do
      (by_parent[parent_id] || []).each do |folder|
        result << folder
        build.call(folder.id)
      end
    end
    build.call(nil)
    result
  end

  # Returns true if this is a root-level folder (no parent)
  def root?
    parent_id.nil?
  end

  # Returns ancestors from immediate parent up to root
  def ancestors
    result = []
    current = parent
    while current
      result << current
      current = current.parent
    end
    result
  end

  # Returns the full path from root to this folder (inclusive)
  def path
    (ancestors.reverse << self)
  end

  # Returns the nesting depth (0 for root folders)
  def depth
    ancestors.length
  end
end
