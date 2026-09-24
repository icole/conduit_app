# frozen_string_literal: true

# An invite link is opened by someone with no session, on whatever host the
# inviter copied it from - which for a self-created community is a domain that
# doesn't resolve yet. So the community has to come from the invitation token,
# falling back to the request host.
#
# Looking the token up across tenants is safe: it is 32 bytes of randomness and
# is itself the credential.
module TenantFromInvitation
  extend ActiveSupport::Concern

  private

  def set_tenant_from_invitation_or_domain
    invitation = find_invitation_across_tenants(invitation_token_for_tenant)

    if invitation
      set_current_tenant(invitation.community)
    else
      set_tenant_from_domain
    end
  end

  # Subclasses say where the token lives: a URL param when accepting, the
  # session afterwards.
  def invitation_token_for_tenant
    params[:id].presence || session[:invitation_token]
  end

  def find_invitation_across_tenants(token)
    return nil if token.blank?

    ActsAsTenant.without_tenant { Invitation.find_by(token: token) }
  end
end
