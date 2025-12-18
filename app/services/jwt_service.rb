# frozen_string_literal: true

class JwtService
  # Use Rails secret key base for signing
  SECRET_KEY = Rails.application.secret_key_base

  # Token expires in 30 days by default
  DEFAULT_EXPIRY = 30.days

  class << self
    def encode(payload, expiry = DEFAULT_EXPIRY)
      # Add expiration to payload
      payload[:exp] = (Time.current + expiry).to_i
      payload[:iat] = Time.current.to_i

      JWT.encode(payload, SECRET_KEY, "HS256")
    end

    def decode(token)
      decoded = JWT.decode(token, SECRET_KEY, true, algorithm: "HS256")
      HashWithIndifferentAccess.new(decoded.first)
    rescue JWT::ExpiredSignature
      Rails.logger.error "JWT token expired"
      nil
    rescue JWT::DecodeError => e
      Rails.logger.error "JWT decode error: #{e.message}"
      nil
    end

    def generate_auth_token(user)
      payload = {
        user_id: user.id,
        community_id: user.community_id,
        email: user.email,
        type: "auth"
      }
      encode(payload)
    end

    def verify_auth_token(token)
      decoded = decode(token)
      return nil unless decoded && decoded[:type] == "auth"

      # Set tenant context for the user lookup
      community = Community.find_by(id: decoded[:community_id])
      return nil unless community

      ActsAsTenant.with_tenant(community) do
        User.find_by(id: decoded[:user_id])
      end
    rescue StandardError => e
      Rails.logger.error "Token verification error: #{e.message}"
      nil
    end
  end
end
