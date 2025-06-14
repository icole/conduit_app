class User < ApplicationRecord
  has_secure_password validations: false

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true

  # Allow OAuth users to not have a password
  validates :password, presence: true, length: { minimum: 6 }, if: -> { provider.blank? }

  def self.from_omniauth(auth)
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
