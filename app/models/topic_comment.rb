class TopicComment < ApplicationRecord
  belongs_to :user
  belongs_to :discussion_topic
  has_many :likes, as: :likeable, dependent: :destroy

  validates :content, presence: true

  scope :recent, -> { order(created_at: :desc) }

  def liked_by?(user)
    likes.exists?(user: user)
  end

  def likes_count
    likes.count
  end
end
