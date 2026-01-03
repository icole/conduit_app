require "digest"

class User < ApplicationRecord
  acts_as_tenant :community

  has_secure_password validations: false

  has_many :posts, dependent: :destroy
  has_many :likes, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :tasks, dependent: :destroy
  has_many :assigned_tasks, class_name: "Task", foreign_key: "assigned_to_user_id", dependent: :nullify

  # Discardable associations - nullify created_by and deleted_by references when user is deleted
  has_many :created_tasks, class_name: "Task", foreign_key: "created_by_id", dependent: :nullify
  has_many :deleted_tasks, class_name: "Task", foreign_key: "deleted_by_id", dependent: :nullify
  has_many :created_posts, class_name: "Post", foreign_key: "created_by_id", dependent: :nullify
  has_many :deleted_posts, class_name: "Post", foreign_key: "deleted_by_id", dependent: :nullify
  has_many :created_comments, class_name: "Comment", foreign_key: "created_by_id", dependent: :nullify
  has_many :deleted_comments, class_name: "Comment", foreign_key: "deleted_by_id", dependent: :nullify
  has_many :created_decisions, class_name: "Decision", foreign_key: "created_by_id", dependent: :nullify
  has_many :deleted_decisions, class_name: "Decision", foreign_key: "deleted_by_id", dependent: :nullify
  has_many :created_discussion_topics, class_name: "DiscussionTopic", foreign_key: "created_by_id", dependent: :nullify
  has_many :deleted_discussion_topics, class_name: "DiscussionTopic", foreign_key: "deleted_by_id", dependent: :nullify
  has_many :created_documents, class_name: "Document", foreign_key: "created_by_id", dependent: :nullify
  has_many :deleted_documents, class_name: "Document", foreign_key: "deleted_by_id", dependent: :nullify
  has_many :created_calendar_events, class_name: "CalendarEvent", foreign_key: "created_by_id", dependent: :nullify
  has_many :deleted_calendar_events, class_name: "CalendarEvent", foreign_key: "deleted_by_id", dependent: :nullify
  has_many :created_chores, class_name: "Chore", foreign_key: "created_by_id", dependent: :nullify
  has_many :deleted_chores, class_name: "Chore", foreign_key: "deleted_by_id", dependent: :nullify
  has_many :created_meals, class_name: "Meal", foreign_key: "created_by_id", dependent: :nullify
  has_many :deleted_meals, class_name: "Meal", foreign_key: "deleted_by_id", dependent: :nullify
  has_many :discussion_topics, dependent: :destroy
  has_many :drive_shares, dependent: :destroy
  belongs_to :invitation, optional: true

  # Chores associations
  has_many :proposed_chores, class_name: "Chore", foreign_key: "proposed_by_id", dependent: :destroy
  has_many :chore_assignments, dependent: :destroy
  has_many :assigned_chores, through: :chore_assignments, source: :chore
  has_many :chore_completions, foreign_key: "completed_by_id", dependent: :destroy

  # Meals associations
  has_many :created_meal_schedules, class_name: "MealSchedule", foreign_key: "created_by_id", dependent: :destroy
  has_many :meal_cooks, dependent: :destroy
  has_many :cooking_meals, through: :meal_cooks, source: :meal
  has_many :meal_rsvps, dependent: :destroy
  has_many :rsvped_meals, through: :meal_rsvps, source: :meal

  # Notifications
  has_many :push_subscriptions, dependent: :destroy
  has_many :in_app_notifications, dependent: :destroy

  validates :email, presence: true, uniqueness: { scope: :community_id }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true

  # Allow OAuth users to not have a password
  # Only validate password when it's being set (new record or password change)
  validates :password, presence: true, length: { minimum: 6 }, if: -> { provider.blank? && (new_record? || password_digest_changed?) }
  validates :password, confirmation: true, if: -> { password.present? }

  # Handle discarded records before destroy - Discardable's default scope hides them from dependent: :destroy
  before_destroy :cleanup_discarded_records

  def self.from_omniauth(auth, invitation_token = nil)
    user = where(provider: auth.provider, uid: auth.uid).first_or_initialize do |user|
      user.email = auth.info.email
      user.name = auth.info.name
      # Don't set a password for OAuth users - they can optionally set one later
      user.avatar_url = auth.info.image
    end

    invitation_token ||= user.invitation&.token
    # Skip invitation check if we're in test environment or if user already exists
    if !Rails.env.test? && user.new_record? && !valid_invitation?(invitation_token)
      raise StandardError, "Access restricted to invited users only"
    end

    # Associate user with invitation if it exists and is valid (only for new users)
    if user.new_record? && invitation_token.present?
      invitation = Invitation.find_by(token: invitation_token)
      if invitation&.valid_for_use?
        user.invitation = invitation
      end
    end

    user
  end

  def self.valid_invitation?(token)
    Invitation.find_by(token: token)&.valid_for_use?
  end

  # Check if user authenticated via Google OAuth
  def google_account?
    provider == "google_oauth2"
  end

  # Stream Chat integration
  def stream_user_id
    # Use string ID for Stream Chat compatibility
    id.to_s
  end

  def stream_user_data
    {
      id: stream_user_id,
      name: name,
      image: avatar_url || gravatar_url,
      role: admin? ? "admin" : "user",
      email: email
    }
  end

  def sync_to_stream_chat
    return unless StreamChatClient.configured?

    StreamChatClient.client.upsert_user(stream_user_data)
  rescue => e
    Rails.logger.error "Failed to sync user #{id} to Stream Chat: #{e.message}"
  end

  def stream_chat_token
    return nil unless StreamChatClient.configured?

    # Generate a Stream Chat token for this user
    StreamChatClient.client.create_token(stream_user_id)
  rescue => e
    Rails.logger.error "Failed to generate Stream Chat token for user #{id}: #{e.message}"
    nil
  end

  private

  def cleanup_discarded_records
    # Delete discarded records that reference this user via user_id
    # These are hidden by Discardable's default_scope and missed by dependent: :destroy
    Task.unscoped.where(user_id: id).discarded.delete_all
    Post.unscoped.where(user_id: id).discarded.delete_all
    Comment.unscoped.where(user_id: id).discarded.delete_all
    DiscussionTopic.unscoped.where(user_id: id).discarded.delete_all
  end

  def gravatar_url
    # Fallback avatar using Gravatar
    hash = Digest::MD5.hexdigest(email.downcase)
    "https://www.gravatar.com/avatar/#{hash}?d=identicon&s=200"
  end
end
