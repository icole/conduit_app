# frozen_string_literal: true

class CommunityMailer < ApplicationMailer
  # Where new-community notifications go. Unset means don't send.
  def self.notify_address
    ENV["CONDUIT_ADMIN_EMAIL"].presence
  end

  # Heads-up that a community was created and is waiting for approval.
  def created(community)
    @community = community
    @founder = ActsAsTenant.with_tenant(community) { User.where(admin: true).order(:id).first }

    mail(to: self.class.notify_address, subject: "New Conduit community pending: #{community.name}")
  end

  # Sent to every admin of a community when it is approved.
  def approved(community)
    @community = community
    admins = ActsAsTenant.with_tenant(community) { User.where(admin: true).pluck(:email) }
    return if admins.empty?

    mail(to: admins, subject: "#{community.name} has been approved on Conduit")
  end
end
