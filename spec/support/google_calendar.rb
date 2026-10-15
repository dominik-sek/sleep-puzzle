# Request and system specs use an empty calendar by default, so rendering a
# booking calendar or integration panel never depends on local Google credentials
# or reaches the network. Individual examples can override this stub.
#
# Empty, not NotConnected: the connected-state specs create an Integration row,
# and a default that claims otherwise would contradict them. A spec about a
# connection that is missing or broken raises what it wants to prove.
#
# Not applied to service specs, which exercise GoogleCalendarService itself.
RSpec.configure do |config|
  %i[request system].each do |type|
    config.before(type: type) do
      allow(GoogleCalendarService).to receive(:call)
        .and_return(instance_double(GoogleCalendarService, busy: [], writable_calendars: []))
    end
  end
end
