# Using the specific google-apis-drive_v3 gem as recommended
require 'google/apis/drive_v3'
require 'googleauth'
require 'googleauth/stores/file_token_store'

module GoogleDriveConfig
  class << self
    def drive_service(auth_code = nil)
      service = Google::Apis::DriveV3::DriveService.new
      service.client_options.application_name = 'Conduit App'

      # Always require OAuth2 authorization for Drive API access
      authorization = authorize(auth_code)
      if authorization
        service.authorization = authorization
        service
      else
        # Return nil if no authorization - don't fall back to API key
        nil
      end
    end

    private

    def authorize(auth_code = nil)
      client_id = ENV['GOOGLE_CLIENT_ID']
      client_secret = ENV['GOOGLE_CLIENT_SECRET']

      return nil if client_id.blank? || client_secret.blank?

      authorizer = Google::Auth::UserAuthorizer.new(
        Google::Auth::ClientId.new(client_id, client_secret),
        [Google::Apis::DriveV3::AUTH_DRIVE_READONLY],
        Google::Auth::Stores::FileTokenStore.new(file: Rails.root.join('tmp', 'token.yaml').to_s)
      )

      # Use the current user's ID if available, otherwise use 'default'
      user_id = Thread.current[:current_user]&.id&.to_s || 'default'
      credentials = authorizer.get_credentials(user_id)

      if credentials.nil?
        if auth_code.present?
          # Use the provided authorization code
          credentials = authorizer.get_and_store_credentials_from_code(
            user_id: user_id, code: auth_code, base_url: 'http://localhost:3000/oauth2callback'
          )
        else
          # Redirect to the authorization URL
          url = authorizer.get_authorization_url(base_url: 'http://localhost:3000/oauth2callback')

          # Store the URL for later use
          Thread.current[:google_auth_url] = url

          # Return nil to indicate that authorization is needed
          return nil
        end
      end

      credentials
    end
  end
end