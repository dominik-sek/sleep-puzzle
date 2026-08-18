# Contact form submissions go through Cloudflare Turnstile. Request specs get a
# verification that always passes, so the suite never reaches the network and
# never depends on whether the machine running it happens to have a real
# TURNSTILE_SECRET in .env.
#
# A spec about the gate itself re-stubs this with what it wants to prove.
RSpec.configure do |config|
  config.before(type: :request) do
    allow(TurnstileVerificationService).to receive(:call)
      .and_return(instance_double(TurnstileVerificationService, verified?: true))
  end
end
