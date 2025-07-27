class MailingList < ApplicationRecord
  has_many :mailing_list_memberships, dependent: :destroy
  has_many :users, through: :mailing_list_memberships

  validates :name, presence: true, uniqueness: true, format: { with: /\A[a-z0-9_-]+\z/, message: "can only contain lowercase letters, numbers, hyphens, and underscores" }
  validates :description, presence: true

  scope :active, -> { where(active: true) }

  def email_address
    "#{name}@#{mailing_list_domain}"
  end

  def member_count
    mailing_list_memberships.count
  end

  def add_user(user)
    users << user unless users.include?(user)
  end

  def remove_user(user)
    users.delete(user)
  end

  def member?(user)
    users.include?(user)
  end

  private

  def mailing_list_domain
    subdomain = Rails.application.credentials.mailing_list_subdomain || ENV["MAILING_LIST_SUBDOMAIN"] || "lists"
    base_domain = Rails.application.credentials.mailing_list_domain || ENV["MAILING_LIST_DOMAIN"] || "example.com"
    "#{subdomain}.#{base_domain}"
  end
end
