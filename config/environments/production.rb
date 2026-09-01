require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # kamal-proxy and Render both terminate TLS and speak plain HTTP to Puma. Without
  # this Rails sees http, and force_ssl would redirect a request that already
  # arrived over TLS -- including kamal-proxy's /up health check, which follows no
  # redirects and would fail every deploy.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  config.active_job.queue_adapter = :solid_queue

  # Booking mail is transactional - a silent failure means a customer who paid
  # never hears back, so surface it and let the job retry.
  config.action_mailer.raise_delivery_errors = true

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = { host: ENV.fetch("APP_HOST", "example.com") }

  # Brevo's HTTP API when there is a key for it, plain SMTP otherwise.
  #
  # Not a preference - Render drops outbound SMTP, so the socket hangs until
  # Net::OpenTimeout and no port or credential fixes it. The API goes out over
  # 443, which is the same way BrevoSubscriptionService already reaches Brevo
  # from that instance. SMTP stays the fallback because it is provider-agnostic
  # and works fine under Kamal, where nothing is blocked.
  #
  # Reads the variable rather than asking BrevoApiDelivery.configured?, because
  # this file is evaluated before autoloading is available and naming the class
  # here would fail at boot.
  config.action_mailer.delivery_method = ENV["BREVO_API_KEY"].present? ? :brevo_api : :smtp
  config.action_mailer.smtp_settings = {
    address: ENV["SMTP_ADDRESS"],
    port: ENV.fetch("SMTP_PORT", 587).to_i,
    user_name: ENV["SMTP_USER_NAME"],
    password: ENV["SMTP_PASSWORD"],
    authentication: :plain,
    enable_starttls_auto: true
  }

  # An unset SMTP_ADDRESS is not an error until the first delivery, and by then
  # it reads as a refused connection rather than as missing configuration -
  # Ruby resolves a nil host to localhost. This does not raise, because a site
  # that cannot send mail should still serve pages, but it does say so once at
  # boot. `bin/rails mail:check` is the same check with a connection attempt.
  config.after_initialize do
    if ENV["BREVO_API_KEY"].blank? && ENV["SMTP_ADDRESS"].blank?
      Rails.logger.warn("[mail] neither BREVO_API_KEY nor SMTP_ADDRESS is set - mail will fail at delivery.")
    end
  end

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  # config.hosts = [
  #   "example.com",     # Allow requests from example.com
  #   /.*\.example\.com/ # Allow requests from subdomains like `www.example.com`
  # ]
  #
  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
