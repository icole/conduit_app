class Comment < ApplicationRecord
  include Discardable

  belongs_to :user
  belongs_to :commentable, polymorphic: true
  belongs_to :post, optional: true # Keep for backward compatibility during transition
  belongs_to :parent, class_name: "Comment", optional: true
  has_many :replies, class_name: "Comment", foreign_key: "parent_id", dependent: :destroy
  has_many :likes, as: :likeable, dependent: :destroy

  validates :content, presence: true

  cascade_discard :replies

  before_create :set_created_by

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

  # Calculate the depth of this comment in the reply tree
  def depth
    return 0 if parent_id.nil?
    1 + (parent&.depth || 0)
  end

  # Get all descendants (replies and replies to replies, etc.)
  def all_descendants
    return Comment.none if replies.empty?

    direct_replies = replies.includes(:user, :replies)
    descendant_ids = direct_replies.pluck(:id)

    # Recursively find all nested replies
    loop do
      next_level = Comment.where(parent_id: descendant_ids).pluck(:id)
      break if next_level.empty?
      descendant_ids += next_level
    end

    Comment.where(id: descendant_ids).includes(:user, :replies)
  end

  # Get the root comment (top-level parent)
  def root_comment
    return self if parent_id.nil?
    parent&.root_comment || self
  end

  # Check if this comment has any descendants
  def has_descendants?
    replies.exists? || replies.joins(:replies).exists?
  end

  private

  def set_created_by
    self.created_by ||= user
  end
end
