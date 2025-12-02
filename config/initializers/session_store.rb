# Configure session cookie settings
Rails.application.config.session_store :cookie_store,
  key: "_conduit_app_session",
  expire_after: 30.days, # Make session persistent for 30 days
  secure: Rails.env.production?, # Use secure cookies in production
  same_site: :lax, # Allow cookies to be sent with navigation
  httponly: true # Prevent JavaScript access for security
