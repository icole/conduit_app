# frozen_string_literal: true

# Concern to detect and handle Turbo Native requests
module TurboNative
  extend ActiveSupport::Concern

  included do
    helper_method :turbo_native_app?
  end

  private

  def turbo_native_app?
    request.user_agent.to_s.include?("Turbo Native")
  end
end
