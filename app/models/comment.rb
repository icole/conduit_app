class Comment < ApplicationRecord
  belongs_to :user
  belongs_to :commentable, polymorphic: true
  belongs_to :post, optional: true # Keep for backward compatibility during transition
  belongs_to :parent, class_name: "Comment", optional: true
  has_many :replies, class_name: "Comment", foreign_key: "parent_id", dependent: :destroy
  has_many :likes, as: :likeable, dependent: :destroy

  validates :content, presence: true

  default_scope { order(created_at: :desc) }
  scope :top_level, -> { where(parent_id: nil) }
  scope :replies_to, ->(comment) { where(parent_id: comment.id) }

  def liked_by?(user)
    likes.exists?(user: user)
  end

  def likes_count
    likes.count
  end

  def top_level?
    parent_id.nil?
  end

  def reply?
    parent_id.present?
  end

  def replies_count
    replies.count
  end
end
