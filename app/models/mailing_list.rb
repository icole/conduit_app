class MailingList < ApplicationRecord
  has_many :mailing_list_memberships, dependent: :destroy
  has_many :users, through: :mailing_list_memberships

  validates :name, presence: true, uniqueness: true, format: { with: /\A[a-z0-9_-]+\z/, message: "can only contain lowercase letters, numbers, hyphens, and underscores" }
  validates :description, presence: true
  validates :mailgun_list_address, uniqueness: true, allow_nil: true

  scope :active, -> { where(active: true) }

  after_create :create_mailgun_list
  after_update :update_mailgun_list
  before_destroy :delete_mailgun_list

  def email_address
    mailgun_list_address || "#{name}@#{mailing_list_domain}"
  end

  def member_count
    mailing_list_memberships.count
  end

  def add_user(user)
    transaction do
      return false if users.include?(user)
      
      users << user
      
      if mailgun_list_address.present?
        begin
          mailgun_service.add_member(mailgun_list_address, user.email, name: user.name)
        rescue MailgunService::MailgunError => e
          Rails.logger.error "Failed to add user to Mailgun list: #{e.message}"
          raise ActiveRecord::Rollback
        end
      end
      
      true
    end
  end

  def remove_user(user)
    transaction do
      return false unless users.include?(user)
      
      users.delete(user)
      
      if mailgun_list_address.present?
        begin
          mailgun_service.remove_member(mailgun_list_address, user.email)
        rescue MailgunService::MailgunError => e
          Rails.logger.error "Failed to remove user from Mailgun list: #{e.message}"
          raise ActiveRecord::Rollback
        end
      end
      
      true
    end
  end

  def member?(user)
    users.include?(user)
  end

  def send_message(from_name, subject, text_body, html_body = nil)
    return false unless mailgun_list_address.present?
    
    begin
      mailgun_service.send_message(mailgun_list_address, from_name, subject, text_body, html_body)
      true
    rescue MailgunService::MailgunError => e
      Rails.logger.error "Failed to send message to Mailgun list: #{e.message}"
      false
    end
  end

  private

  def mailing_list_domain
    subdomain = Rails.application.credentials.mailing_list_subdomain || ENV["MAILING_LIST_SUBDOMAIN"] || "lists"
    base_domain = Rails.application.credentials.mailing_list_domain || ENV["MAILING_LIST_DOMAIN"] || "example.com"
    "#{subdomain}.#{base_domain}"
  end

  def mailgun_service
    @mailgun_service ||= MailgunService.new
  end

  def create_mailgun_list
    return unless active?
    
    begin
      list_address = mailgun_service.create_mailing_list(name, description)
      update_column(:mailgun_list_address, list_address)
      
      # Add existing members to the Mailgun list
      users.find_each do |user|
        mailgun_service.add_member(list_address, user.email, name: user.name)
      end
    rescue MailgunService::MailgunError => e
      Rails.logger.error "Failed to create Mailgun list: #{e.message}"
    end
  end

  def update_mailgun_list
    return unless mailgun_list_address.present? && active?
    return unless saved_change_to_name? || saved_change_to_description?
    
    begin
      mailgun_service.update_mailing_list(
        mailgun_list_address,
        name: saved_change_to_name? ? name : nil,
        description: saved_change_to_description? ? description : nil
      )
    rescue MailgunService::MailgunError => e
      Rails.logger.error "Failed to update Mailgun list: #{e.message}"
    end
  end

  def delete_mailgun_list
    return unless mailgun_list_address.present?
    
    begin
      mailgun_service.delete_mailing_list(mailgun_list_address)
    rescue MailgunService::MailgunError => e
      Rails.logger.error "Failed to delete Mailgun list: #{e.message}"
    end
  end
end
