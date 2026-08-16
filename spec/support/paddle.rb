# The admin catalogue screens ask Paddle for the account's prices on every render.
# Request specs get an empty catalogue by default so the suite never reaches the
# network; a spec that cares about prices stubs the call itself.
#
# Not applied to service specs, which stub Paddle::Price directly in order to
# exercise PaddlePriceCatalogService itself.
RSpec.configure do |config|
  config.before(type: :request) do
    allow(PaddlePriceCatalogService).to receive(:call).and_return([])
  end
end
