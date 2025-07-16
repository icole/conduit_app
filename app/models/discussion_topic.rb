class DiscussionTopic < ApplicationRecord
  belongs_to :user
  has_many :topic_comments, -> { order(:created_at) }, dependent: :destroy
  has_many :likes, as: :likeable, dependent: :destroy

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
    topic_comments.count
  end

  def latest_activity
    latest_comment = topic_comments.order(created_at: :desc).first
    latest_comment ? latest_comment.created_at : created_at
  end
end
