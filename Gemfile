source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.3"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use Vite for JS/CSS bundling [https://vite-ruby.netlify.app/]
gem "vite_rails"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Web UI for the Solid Queue tables, mounted at /admin/jobs. A queue with no
# worker looks exactly like a queue with nothing to do, which is how a mail
# outage and a stuck Paddle webhook both went unnoticed once.
gem "mission_control-jobs"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 2.0"

# image_processing 2.0 made its backends opt-in; Active Storage defaults to the vips processor
gem "ruby-vips", "~> 2.0"

gem "rails-i18n"

# Pagination [https://ddnexus.github.io/pagy/]
gem "pagy"

gem "omniauth"

gem "omniauth-google-oauth2"

gem "omniauth-rails_csrf_protection"


group :development, :test do
  # Loads .env into ENV for any boot path (console, runner, server), not just `bin/dev`/foreman
  gem "dotenv-rails"

  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # RSpec for Rails [https://github.com/rspec/rspec-rails]
  gem "rspec-rails"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # Run rails server and vite dev server together [https://github.com/ddollar/foreman]
  gem "foreman", require: false

  # Auto-annotate models with schema info [https://github.com/drwl/annotaterb]
  gem "annotaterb"

  # Opens outgoing mail in the browser instead of trying to deliver it
  gem "letter_opener"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"

  # Code coverage reporting [https://github.com/simplecov-ruby/simplecov]
  gem "simplecov", require: false
end

gem "devise", "~> 5.0"

gem "view_component"

gem "turbo-rails", "~> 2.0"

gem "google-apis-calendar_v3", "~> 0.57.0"

gem "googleauth", "~> 1.17"

gem "rails_semantic_logger"

gem "pay", "~> 11.5"

gem "paddle", "~> 2.9"

# Error tracking and request tracing. Inert without SENTRY_DSN, so development
# and CI never phone home; see config/initializers/sentry.rb.
gem "sentry-ruby"
gem "sentry-rails"

# Postgres dashboard at /admin/db - slow queries, index suggestions, bloat.
# Reads the database that is already there, so it needs no Redis and no second
# service, which is the whole reason it is here rather than an APM agent.
gem "pghero"
