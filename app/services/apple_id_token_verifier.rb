# frozen_string_literal: true

# Verifies a Sign in with Apple identity token: an RS256 JWT signed with one
# of Apple's published keys, issued by Apple, for our iPhone app, unexpired.
# Apple's keys are cached for a day and refetched when a token names a key
# we haven't seen (Apple rotates them).
class AppleIdTokenVerifier
  KEYS_URI = "https://appleid.apple.com/auth/keys"
  ISSUER = "https://appleid.apple.com"

  class << self
    # The token's claims, or nil if it isn't a valid token for our app
    def verify(identity_token)
      return nil if identity_token.blank?

      claims, _header = JWT.decode(identity_token, nil, true,
        algorithms: [ "RS256" ], jwks: method(:jwks),
        iss: ISSUER, verify_iss: true, aud: audiences, verify_aud: true)
      claims
    rescue JWT::DecodeError => e
      Rails.logger.warn "Apple identity token refused: #{e.class}"
      nil
    end

    private

    # The iPhone app's bundle ID; more than one for test builds if needed
    def audiences
      ENV.fetch("APPLE_SIGN_IN_AUDIENCES", "com.colecoding.ConduitApp").split(",").map(&:strip)
    end

    def jwks(options = {})
      Rails.cache.delete("apple_sign_in_keys") if options[:kid_not_found]
      keys = Rails.cache.fetch("apple_sign_in_keys", expires_in: 1.day) { fetch_keys }
      JWT::JWK::Set.new(keys)
    end

    def fetch_keys
      response = Net::HTTP.get_response(URI(KEYS_URI))
      raise JWT::DecodeError, "Apple keys unavailable (#{response.code})" unless response.code == "200"

      JSON.parse(response.body)
    end
  end
end
