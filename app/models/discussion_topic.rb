class DiscussionTopic < ApplicationRecord
  belongs_to :user
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :likes, as: :likeable, dependent: :destroy
  has_rich_text :description

  validates :title, presence: true
  validates :description, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_activity, -> { order(last_activity_at: :desc) }

  def liked_by?(user)
    likes.exists?(user: user)
  end

  def likes_count
    likes.count
  end

  def comments_count
    comments.count
  end

  def latest_activity
    latest_comment = comments.order(created_at: :desc).first
    latest_comment ? latest_comment.created_at : created_at
  end

  # Helper method to check if user has commented (for UI state)
  def commented_by?(user)
    comments.exists?(user: user)
  end
end
