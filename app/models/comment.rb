class Comment < ApplicationRecord
  belongs_to :user
  belongs_to :post
  has_many :likes, as: :likeable, dependent: :destroy

  validates :content, presence: true

  default_scope { order(created_at: :desc) }

  def liked_by?(user)
    likes.exists?(user: user)
  end

  def likes_count
    likes.count
  end
end
