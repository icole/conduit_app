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
  end
end
