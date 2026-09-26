# frozen_string_literal: true

# Include the standard Turbo Native navigation module from turbo-rails gem.
# This provides hotwire_native_app? and turbo_native_app? helpers that detect
# user agents containing "Turbo Native" or "Hotwire Native".
#
# See: https://github.com/hotwired/turbo-rails
module TurboNative
  extend ActiveSupport::Concern

  included do
    include Turbo::Native::Navigation
    helper_method :legacy_ios_app?
  end

  # iOS builds before "Conduit iOS/2" never open modals, and a Turbo form
  # redirect pushes a new screen there, so forms submit as full page loads.
  def legacy_ios_app?
    request.user_agent.to_s.include?("Conduit iOS (")
  end
end
