# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# docker build -t sleep_puzzle .
# docker run -d -p 80:80 --env-file .env.production --name sleep_puzzle sleep_puzzle
#
# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=4.0.5
# Keep NODE_VERSION in sync with .node-version. Vite needs its own runtime at
# build time; the final image ships no Node at all.
ARG NODE_VERSION=20

# Source of the Node toolchain copied into the build stage. Pinned to bookworm so
# the binary is always linked against an older glibc than the Ruby base image.
FROM docker.io/library/node:$NODE_VERSION-bookworm-slim AS node

FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Rails app lives here
WORKDIR /rails

# Install base packages
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y curl ffmpeg libjemalloc2 libvips postgresql-client && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so

# Set production environment variables and enable jemalloc for reduced memory usage and latency.
# Test gems are excluded alongside development ones: nothing in the image runs specs.
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so" \
    RUBY_YJIT_ENABLE="1"


# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libvips libyaml-dev pkg-config

# Node + npm for `vite build`, lifted from the official Node image rather than
# compiled from source, which keeps this layer to a few seconds.
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
    ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

# Install application gems
COPY vendor/* ./vendor/
COPY Gemfile Gemfile.lock ./

RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    # -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
    bundle exec bootsnap precompile -j 1 --gemfile

# Install JS packages in their own layer so app-code edits don't re-run npm.
# --include=dev is deliberate: vite, tailwindcss and vite-plugin-ruby all live in
# devDependencies, and RAILS_ENV=production would otherwise have npm skip them.
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm,sharing=locked \
    npm ci --include=dev

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times.
# -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
RUN bundle exec bootsnap precompile -j 1 app/ lib/

# Precompiling assets for production without requiring the real SECRET_KEY_BASE.
# vite_rails hooks `vite build` into this task, so it needs the Node toolchain above.
# Left alone it would also re-run `npm ci` here, wiping the layer installed above and
# re-downloading every package without the cache mount, so that half is skipped.
# node_modules is build-only weight, so drop it once the bundles exist.
RUN SECRET_KEY_BASE_DUMMY=1 \
    VITE_RUBY_SKIP_ASSETS_PRECOMPILE_INSTALL=true \
    ./bin/rails assets:precompile && \
    rm -rf node_modules


# Final stage for app image
FROM base

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000

# Copy built artifacts: gems, application
COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Thruster terminates on HTTP_PORT and proxies to Puma on PORT, so the probe targets
# the former. Kamal runs its own check, but this keeps `docker run` and compose
# deployments honest about whether the app actually booted.
HEALTHCHECK --interval=30s --timeout=5s --start-period=45s --retries=3 \
  CMD curl -fsS "http://localhost:${HTTP_PORT:-80}/up" || exit 1

# Start server via Thruster by default, this can be overwritten at runtime
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
