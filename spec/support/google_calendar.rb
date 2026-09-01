# Anything that renders a booking calendar or the Google integration panel asks
# Google on every request. Request specs get a service that answers nothing, so
# the suite never reaches the network and never depends on whether the machine
# running it happens to have GOOGLE_CLIENT_ID in .env - without this, a spec
# passes locally and dies in CI on "Client id can not be nil", raised while
# building the authorizer, before any of the controller's rescues can help.
#
# Empty, not NotConnected: the connected-state specs create an Integration row,
# and a default that claims otherwise would contradict them. A spec about a
# connection that is missing or broken raises what it wants to prove.
#
# Not applied to service specs, which exercise GoogleCalendarService itself.
RSpec.configure do |config|
  config.before(type: :request) do
    allow(GoogleCalendarService).to receive(:call)
      .and_return(instance_double(GoogleCalendarService, busy: [], writable_calendars: []))
  end
end
