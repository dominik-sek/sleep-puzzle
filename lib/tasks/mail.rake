namespace :mail do
  # Written after a deploy where mail failed at TCPSocket#initialize with no
  # SMTP conversation at all. Unset SMTP_ADDRESS is not an error at boot: Ruby
  # resolves a nil host to localhost, so the failure surfaces much later as a
  # connection refused to a host nobody configured. This says so up front.
  desc "Check SMTP configuration and connectivity: bin/rails mail:check"
  task check: :environment do
    settings = ActionMailer::Base.smtp_settings
    address = settings[:address]
    port = settings[:port]

    puts "delivery_method: #{ActionMailer::Base.delivery_method}"
    puts "address:         #{address.presence || '(unset)'}"
    puts "port:            #{port.presence || '(unset)'}"
    puts "user_name:       #{settings[:user_name].presence || '(unset)'}"
    # Presence only. This runs on a deployed box and the output goes to a log.
    puts "password:        #{settings[:password].present? ? '(set)' : '(unset)'}"
    puts "from:            #{ENV['MAIL_FROM'].presence || '(unset, falling back)'}"
    puts

    # Blank and "localhost" are the same bug wearing two hats: production.rb sets
    # `address: ENV["SMTP_ADDRESS"]`, which is nil when unset, while an
    # unconfigured ActionMailer defaults to localhost:25. Neither is ever a real
    # mail host here, and both fail at connect rather than as a config error.
    if address.blank? || address.in?(%w[ localhost 127.0.0.1 ::1 ])
      abort "SMTP_ADDRESS is not configured (address resolves to #{address.presence.inspect}). " \
            "Set SMTP_ADDRESS, SMTP_PORT, SMTP_USER_NAME and SMTP_PASSWORD in the " \
            "environment. Delivery fails at connect, not at boot, so this is the " \
            "first place it shows up."
    end

    require "socket"
    print "Connecting to #{address}:#{port}... "

    begin
      Socket.tcp(address, port, connect_timeout: 10) { |socket| socket.close }
      puts "ok"
    rescue SocketError => e
      abort "failed.\n#{e.class}: #{e.message}\nThe hostname does not resolve - check SMTP_ADDRESS for a typo."
    rescue Errno::ECONNREFUSED => e
      abort "failed.\n#{e.class}: #{e.message}\nNothing is listening there. Wrong port, or SMTP_ADDRESS is pointing at this container."
    rescue Errno::ETIMEDOUT, Errno::EHOSTUNREACH => e
      abort "failed.\n#{e.class}: #{e.message}\nThe connection hung rather than being refused, which is what an " \
            "outbound firewall looks like. Check whether the host blocks this port, and try 587 or 465."
    end

    puts
    puts "TCP reachable. That clears the failure in this task's header comment; " \
         "anything past this point is auth or TLS, which only a real delivery exercises."
  end
end
