# Rate limiting and request throttling
class Rack::Attack
  # Throttle login attempts by IP (20 attempts per 15 minutes)
  throttle("logins/ip", limit: 20, period: 15.minutes) do |req|
    req.ip if req.post? && req.path.match?(%r{\A/(login|sessions|api/v1/login|api/v1/google_auth)\z})
  end

  # Throttle login attempts by email parameter (10 attempts per 15 minutes)
  throttle("logins/email", limit: 10, period: 15.minutes) do |req|
    if req.post? && req.path.match?(%r{\A/(login|sessions|api/v1/login)\z})
      req.params.dig("session", "email")&.downcase&.strip ||
        req.params.dig("email")&.downcase&.strip
    end
  end

  # Throttle password reset requests by IP (5 per 30 minutes)
  throttle("password_resets/ip", limit: 5, period: 30.minutes) do |req|
    req.ip if req.post? && req.path == "/password_reset"
  end

  # Throttle registration attempts by IP (5 per hour)
  throttle("registrations/ip", limit: 5, period: 1.hour) do |req|
    req.ip if req.post? && req.path == "/register"
  end

  # General request throttle by IP (300 requests per 5 minutes)
  throttle("requests/ip", limit: 300, period: 5.minutes, &:ip)

  # Custom response for throttled requests
  self.throttled_responder = lambda do |request|
    match_data = request.env["rack.attack.match_data"] || {}

    headers = {
      "content-type" => "text/plain",
      "retry-after" => match_data[:period].to_s
    }

    [ 429, headers, [ "Too Many Requests" ] ]
  end
end
