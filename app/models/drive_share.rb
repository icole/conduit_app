# frozen_string_literal: true

class DriveShare < ApplicationRecord
  belongs_to :user

  validates :folder_id, presence: true
  validates :user_id, presence: true
  validates :shared_at, presence: true

  # Check if a folder is already shared with a specific user
  def self.folder_shared_with_user?(folder_id, user)
    exists?(folder_id: folder_id, user_id: user.id)
  end
end
