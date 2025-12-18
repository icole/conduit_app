class Post < ApplicationRecord
  acts_as_tenant :community

  belongs_to :user
  has_many :likes, as: :likeable, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy
  validates :content, presence: true

  def liked_by?(user)
    likes.exists?(user: user)
  end

  def commented_by?(user)
    comments.exists?(user: user)
  end

  def likes_count
    likes.count
  end

  def comments_count
    comments.count
  end
end
