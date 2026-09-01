# frozen_string_literal: true

# Error tracking and request tracing.
#
# Production only, and only with a DSN.
#
# Both halves matter. The SDK tolerates a nil DSN on its own, but an explicit
# guard keeps the subscribers and the background sender thread from being
# installed at all - this app runs its jobs as threads inside Puma, so every
# thread it does not need is memory it keeps.
#
# The environment check is not belt-and-braces: dotenv loads .env for every
# boot path here, so a developer with a real DSN in it would otherwise have
# every local and test-run exception land in the production project. It also
# breaks the suite outright. Sentry patches Net::HTTP by prepending a module to
# collect request breadcrumbs, and rspec-mocks refuses to stub a method defined
# on a prepended module - `allow_any_instance_of(Net::HTTP)`, which is how the
# Turnstile and Brevo specs stand in for the network, dies with "not supported".
#
# config.enabled_environments would not do this. Patches are applied by
# Sentry.init before it consults that list, so the prepend happens regardless.
return unless Rails.env.production?
return if ENV["SENTRY_DSN"].blank?

Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]

  # Staging and production both deploy this image and both report, so the
  # environment cannot be read off Rails.env - it is "production" in each. Name
  # it explicitly per instance instead, or events from the two pile into one
  # stream and a staging crash pages you about a real one.
  config.environment = ENV.fetch("SENTRY_ENVIRONMENT", Rails.env)

  # Groups events by deploy, and gets the backtrace linked to the right commit.
  # Render exposes the SHA it built; Kamal exposes the version it rolled out.
  config.release = ENV["RENDER_GIT_COMMIT"] || ENV["KAMAL_VERSION"]

  # The log lines leading up to the exception, which is most of what makes a
  # backtrace readable. :active_support_logger picks up Rails' own instrumented
  # events; the app's logging goes through rails_semantic_logger to STDOUT and
  # stays there.
  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]

  # Never send session cookies, IP addresses, or the request body. What is left
  # is still enough to find the request - path, params (filtered), the user id
  # attached in ApplicationController - and this site takes bookings from named
  # people, so the body is not something to hand a third party by default.
  # Request params are additionally run through config.filter_parameters, where
  # :email already is.
  config.send_default_pii = false
  config.enable_logs = true
  config.enabled_patches = [:logger]

  # Performance tracing. A sampled fraction of requests carries a full span
  # tree - controller, each SQL query, each partial - which is where an N+1 or
  # a slow query shows up as something other than "the page feels slow".
  #
  # /up is excluded because the load balancer hits it constantly and a health
  # check has nothing to say about performance; it would just spend the quota.
  traced = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", "0.1").to_f
  config.traces_sampler = lambda do |context|
    next 0.0 if context.dig(:env, "PATH_INFO") == "/up"

    context[:parent_sampled] || traced
  end

  # Rails rescues these into 404s and 400s; they are routine traffic, not
  # defects, and left in they bury the real errors.
  config.excluded_exceptions += [
    "ActionController::BadRequest",
    "ActionController::UnknownFormat",
    "ActionDispatch::Http::MimeNegotiation::InvalidType"
  ]
end
