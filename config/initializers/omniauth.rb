#todo: change host after domain done
OmniAuth.config.full_host = Rails.env.production? ? 'https://domain.com' : "http://localhost:#{ENV.fetch('PORT', 3000)}"
