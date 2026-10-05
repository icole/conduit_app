# frozen_string_literal: true

# ActiveStorage Authentication & Authorization
#
# This implementation follows the approach used by Hey (Basecamp) for securing
# ActiveStorage files. Instead of creating custom controllers, we inject
# authentication directly into ActiveStorage's controllers using on_load hooks.
#
# Reference: https://discuss.rubyonrails.org/t/activestorage-authentication/79273
#
# How it works:
# 1. Authentication module is included in all ActiveStorage controllers
# 2. Models with attachments can implement `accessible_to?(user)` for fine-grained access
# 3. Otherwise a file is shared within its owner's community (rich text images:
#    the record the text belongs to), and refused when there's no telling

module ActiveStorage
  module Authorization
    extend ActiveSupport::Concern

    included do
      before_action :require_authentication
      before_action :authorize_access, only: :show
    end

    private

    def require_authentication
      unless current_user
        if browser_request?
          redirect_to main_app.login_path, alert: "Please log in to access this file."
        else
          head :unauthorized
        end
      end
    end

    def authorize_access
      return unless current_user # Already handled by require_authentication

      # Find the record that owns this blob and check authorization
      record = find_record_for_blob
      return unless record # No record found, allow access (blob exists independently)

      head :forbidden unless owner_allows?(record)
    end

    # The owner decides. Rich text's images belong to an ActionText::RichText,
    # so ask the record the text belongs to (e.g. a meal). An owner without
    # accessible_to? is shared within its community; anything else is refused.
    # (Authentication alone used to be enough, across communities.)
    def owner_allows?(record)
      owner = record.is_a?(ActionText::RichText) ? record.record : record
      return false unless owner

      if owner.respond_to?(:accessible_to?)
        owner.accessible_to?(current_user)
      elsif owner.respond_to?(:community_id)
        owner.community_id == current_user.community_id
      else
        false
      end
    end

    def find_record_for_blob
      blob = @blob || (@representation&.blob)
      return nil unless blob

      # Find the attachment that references this blob (without tenant scope)
      ActsAsTenant.without_tenant do
        attachment = ActiveStorage::Attachment.find_by(blob_id: blob.id)
        attachment&.record
      end
    end

    def current_user
      return @current_user if defined?(@current_user)

      @current_user = if session[:user_id]
        # Must query without tenant scope since tenant isn't set yet
        ActsAsTenant.without_tenant { User.find_by(id: session[:user_id]) }
      end
    end

    def browser_request?
      request.headers["Accept"]&.include?("text/html")
    end
  end
end

# Inject authorization into ActiveStorage controllers when they load
Rails.application.config.to_prepare do
  ActiveStorage::Blobs::RedirectController.include(ActiveStorage::Authorization)
  ActiveStorage::Blobs::ProxyController.include(ActiveStorage::Authorization)
  ActiveStorage::Representations::RedirectController.include(ActiveStorage::Authorization)
  ActiveStorage::Representations::ProxyController.include(ActiveStorage::Authorization)

  # Direct uploads also require authentication
  ActiveStorage::DirectUploadsController.include(ActiveStorage::Authorization)

  # Disk service (local storage) - the actual file serving endpoint
  # Even though URLs are signed with expiration, require auth for defense in depth
  ActiveStorage::DiskController.include(ActiveStorage::Authorization)
end
