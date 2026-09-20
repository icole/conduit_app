# frozen_string_literal: true

class CommunityMailer < ApplicationMailer
  # Sent to every admin of a community when it is approved.
  def approved(community)
    @community = community
    admins = ActsAsTenant.with_tenant(community) { User.where(admin: true).pluck(:email) }
    return if admins.empty?

    mail(to: admins, subject: "#{community.name} has been approved on Conduit")
  end
end
