# frozen_string_literal: true

ActsAsTenant.configure do |config|
  # Require a tenant to be set (will raise error if not set)
  # In production, this prevents accidental data leaks
  config.require_tenant = !Rails.env.test?
end
