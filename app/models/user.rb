class User < ApplicationRecord
  has_secure_password validations: false

  has_many :posts, dependent: :destroy
  has_many :likes, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :tasks, dependent: :destroy

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true

  # Allow OAuth users to not have a password
  validates :password, presence: true, length: { minimum: 6 }, if: -> { provider.blank? }

  def self.allowed_emails
    # Store allowed emails in environment variable
    ENV["ALLOWED_EMAILS"]&.split(",")&.map(&:strip) || []
  end

  def self.from_omniauth(auth)
    unless Rails.env.test? || allowed_emails.include?(auth.info.email)
      raise StandardError, "Access restricted to invited users only"
    end

    where(provider: auth.provider, uid: auth.uid).first_or_initialize do |user|
      user.email = auth.info.email
      user.name = auth.info.name
      user.password = SecureRandom.hex(16) if user.new_record?
      user.avatar_url = auth.info.image
    end
  end

  def has_notifications?
    # TODO: Implement logic to check if the user has notifications
    false
  end
end
