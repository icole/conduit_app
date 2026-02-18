source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.2"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.6"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails"
# Heroicons for Rails [https://github.com/bharget/heroicon]
gem "heroicon"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.21"

# Multi-tenancy support [https://github.com/ErwinM/acts_as_tenant]
gem "acts_as_tenant", "~> 1.0"

# Soft delete for content models [https://github.com/jhawthorn/discard]
gem "discard", "~> 1.3"

# Audit trail for model changes [https://github.com/paper-trail-gem/paper_trail]
gem "paper_trail", "~> 17.0"

# JWT for secure token generation
gem "jwt", "~> 2.7"

# Authentication
gem "omniauth", "~> 2.1"
gem "omniauth-google-oauth2", "~> 1.1"
gem "omniauth-rails_csrf_protection", "~> 2.0"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

# Google Drive API - Using specific service gem as recommended
gem "google-apis-drive_v3", "~> 0.77.0"
gem "googleauth", "~> 1.16"
gem "google-apis-calendar_v3", "~> 0.51.0"

gem "pstore"
gem "simple_calendar"

# Stream Chat for HOA community messaging
gem "stream-chat-ruby", "~> 3.23"

# Web Push notifications
gem "webpush", "~> 1.1"

# Sentry for error tracking
gem "sentry-ruby"
gem "sentry-rails"

# Resend for transactional email
gem "resend", "~> 0.17"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # Load environment variables from .env file
  gem "dotenv-rails"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
  gem "claude-on-rails"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
  gem "rails-controller-testing"
  # Pin minitest to 5.x until Rails 8.1 compatibility is resolved
  gem "minitest", "~> 6.0"
end

gem "jsbundling-rails", "~> 1.3"
