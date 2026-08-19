require 'rails_helper'

RSpec.describe GoogleCalendarService do
  let(:authorizer) { instance_double(Google::Auth::WebUserAuthorizer) }

  before { allow(AuthorizeCalendarService).to receive(:call).and_return(authorizer) }

  describe "when there is no usable calendar" do
    # Nothing in the token store, because nobody has been through the OAuth flow
    # in the panel yet. This used to hand back a service with a nil authorization,
    # which looked fine until the first API call answered 401.
    it "refuses to build a service when nothing is connected" do
      allow(authorizer).to receive(:get_credentials).and_return(nil)

      expect { described_class.call }
        .to raise_error(described_class::NotConnected, /no Google Calendar is connected/)
    end

    # A refresh token Google has since dropped: it answers 400 "Token has been
    # expired or revoked" as soon as the gem tries to mint an access token from
    # it, which surfaced as a Signet error nothing up the stack was catching.
    it "reports a dead stored grant as not connected" do
      allow(authorizer).to receive(:get_credentials)
        .and_raise(Signet::AuthorizationError.new("Token has been expired or revoked"))

      expect { described_class.call }
        .to raise_error(described_class::NotConnected, /no longer valid/)
    end

    # the distinction the class exists to draw — callers treat a missing
    # connection differently from a call that happened to fail
    it "is not mistaken for a Google::Apis::Error" do
      expect(described_class::NotConnected.new).not_to be_a(Google::Apis::Error)
    end
  end

  it "builds a service when the grant works" do
    allow(authorizer).to receive(:get_credentials)
      .and_return(instance_double(Google::Auth::UserRefreshCredentials))

    expect(described_class.call).to be_a(described_class)
  end
end
