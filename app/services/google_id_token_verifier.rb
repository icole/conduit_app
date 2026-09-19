# frozen_string_literal: true

# Verifies a Google ID token via Google's tokeninfo endpoint and checks that
# its audience is one of our configured client IDs (web, iOS, Android).
class GoogleIdTokenVerifier
  TOKENINFO_URI = "https://oauth2.googleapis.com/tokeninfo"

  class << self
    # Returns the token's claims as a Hash, or nil if the token is invalid,
    # not issued for one of our client IDs, or verification fails.
    def verify(id_token)
      return nil if id_token.blank?

      client_ids = valid_client_ids
      if client_ids.empty?
        Rails.logger.error "No Google Client IDs configured in environment variables"
        return nil
      end

      data = fetch_tokeninfo(id_token)
      return nil unless data

      unless client_ids.include?(data["aud"])
        Rails.logger.error "Google ID token has invalid audience: #{data["aud"]}"
        return nil
      end

      data
    end

    private

    # GOOGLE_ANDROID_CLIENT_IDS can be comma-separated for multiple IDs (debug, release, play store)
    def valid_client_ids
      android_client_ids = ENV["GOOGLE_ANDROID_CLIENT_IDS"]&.split(",")&.map(&:strip) || []

      [
        ENV["GOOGLE_CLIENT_ID"],      # Web client ID
        ENV["GOOGLE_IOS_CLIENT_ID"],  # iOS client ID
        *android_client_ids
      ].compact.uniq
    end

    def fetch_tokeninfo(id_token)
      uri = URI(TOKENINFO_URI)
      uri.query = URI.encode_www_form(id_token: id_token)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER

      response = http.request(Net::HTTP::Get.new(uri))

      unless response.code == "200"
        Rails.logger.error "Google ID token verification failed: #{response.code}"
        return nil
      end

      JSON.parse(response.body)
    rescue StandardError => e
      Rails.logger.error "Error verifying Google ID token: #{e.message}"
      nil
    end
  end
end
