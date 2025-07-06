class Invitation < ApplicationRecord
  has_many :users

  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  before_validation :generate_token, on: :create
  before_validation :set_expiration, on: :create

  scope :valid, -> { where(used_at: nil).where("expires_at > ?", Time.current) }

  # Default expiration period (2 weeks)
  EXPIRATION_PERIOD = 2.weeks

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(32)
  end

  def set_expiration
    self.expires_at ||= Time.current + EXPIRATION_PERIOD
  end

  def expired?
    expires_at < Time.current
  end

  def used?
    users.exists?
  end

  def valid_for_use?
    !expired?
  end

  # Count how many users have used this invitation
  def usage_count
    users.count
  end
end
