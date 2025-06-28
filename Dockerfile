# syntax=docker/dockerfile:1
# check=error=true

ARG RUBY_VERSION=3.4.4
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base
ARG CACHE_BREAKER=1


# Rails app lives here
WORKDIR /rails

# Install base packages
RUN apt-get update -qq && \
  apt-get install --no-install-recommends -y curl libjemalloc2 libvips postgresql-client && \
  rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set production environment
ENV RAILS_ENV="production" \
  BUNDLE_DEPLOYMENT="1" \
  BUNDLE_PATH="/usr/local/bundle" \
  BUNDLE_WITHOUT="development"

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems
RUN apt-get update -qq && \
  apt-get install --no-install-recommends -y build-essential git libpq-dev libyaml-dev pkg-config && \
  rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
  rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
  bundle exec bootsnap precompile --gemfile

# Add Node + Yarn
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
  apt-get install -y nodejs && \
  npm install --global yarn

# Install Node deps BEFORE copying full app (for caching)
COPY package.json yarn.lock ./
RUN yarn install

RUN ls -al node_modules/daisyui || (echo "daisyui not found" && false)

# Now copy the full app
COPY . .

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/

RUN echo "🧪 node_modules exists:" && ls -la node_modules && \
  echo "🧪 daisyui exists:" && ls -la node_modules/daisyui && \
  echo "🧪 tailwind config:" && cat tailwind.config.js

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile --trace

# Final stage for app image
FROM base

# Copy built artifacts: gems, application
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
  useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
  chown -R rails:rails db log storage tmp
USER 1000:1000

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start server via Thruster by default, this can be overwritten at runtime
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]