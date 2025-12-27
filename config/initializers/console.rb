# frozen_string_literal: true

Rails.application.configure do
  console do
    def set_tenant(slug_or_community)
      community = slug_or_community.is_a?(Community) ? slug_or_community : Community.find_by(slug: slug_or_community)
      ActsAsTenant.current_tenant = community
      puts "Tenant: #{community&.name || 'none'}"
      community
    end

    set_tenant("crow-woods")
  end
end
