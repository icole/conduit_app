class Post < ApplicationRecord
  include Discardable

  acts_as_tenant :community

  belongs_to :user
  has_many :likes, as: :likeable, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy

  validates :content, presence: true

  cascade_discard :comments

  before_create :set_created_by

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

  private

  def set_created_by
    self.created_by ||= user
  end
end
