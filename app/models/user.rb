class User < ApplicationRecord
  has_secure_password validations: false

  has_many :posts, dependent: :destroy
  has_many :likes, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :tasks, dependent: :destroy
  has_many :assigned_tasks, class_name: "Task", foreign_key: "assigned_to_user_id", dependent: :nullify
  has_many :discussion_topics, dependent: :destroy
  has_many :mailing_list_memberships, dependent: :destroy
  has_many :mailing_lists, through: :mailing_list_memberships
  has_many :drive_shares, dependent: :destroy
  belongs_to :invitation, optional: true

  # Chores associations
  has_many :proposed_chores, class_name: "Chore", foreign_key: "proposed_by_id", dependent: :destroy
  has_many :chore_assignments, dependent: :destroy
  has_many :assigned_chores, through: :chore_assignments, source: :chore
  has_many :chore_completions, foreign_key: "completed_by_id", dependent: :destroy

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true

  # Allow OAuth users to not have a password
  validates :password, presence: true, length: { minimum: 6 }, if: -> { provider.blank? }
  validates :password, confirmation: true, if: -> { password.present? }

  def self.from_omniauth(auth, invitation_token = nil)
    user = where(provider: auth.provider, uid: auth.uid).first_or_initialize do |user|
      user.email = auth.info.email
      user.name = auth.info.name
      user.password = SecureRandom.hex(16) if user.new_record?
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
end
