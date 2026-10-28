# Discovery is public, independent of browser version, locale and signed-in user.
class UcpDiscoveryController < ActionController::Base
  VERSION = "2026-08-25".freeze
  ORIGIN = "https://sleeppuzzle.com".freeze

  def show
    services = {
      "com.sleeppuzzle.shopping" => [ {
        version: VERSION,
        spec: "#{ORIGIN}/ucp/specification",
        schema: "#{ORIGIN}/ucp/services/browser.openapi.json",
        transport: "rest",
        endpoint: ORIGIN
      } ]
    }
    endpoints = {
      catalog: "#{ORIGIN}/products",
      checkout: "#{ORIGIN}/cart",
      authentication: "#{ORIGIN}/users/sign_in"
    }
    capabilities = {
      "com.sleeppuzzle.shopping.browser_checkout" => [ {
        version: VERSION,
        spec: "#{ORIGIN}/ucp/specification",
        schema: "#{ORIGIN}/ucp/schemas/browser-checkout.json",
        config: endpoints.merge(payment_provider: "paddle", requires_authentication: true)
      } ]
    }

    render json: {
      ucp: { version: VERSION, services: services, capabilities: capabilities, payment_handlers: {} },
      protocol_version: VERSION, services: services, capabilities: capabilities, endpoints: endpoints
    }
  end

  def specification
    render plain: Rails.root.join("docs/ucp/specification.md").read, content_type: "text/markdown"
  end

  def schema
    render body: Rails.root.join("docs/ucp/browser-checkout.json").read, content_type: "application/json"
  end

  def service_schema
    render body: Rails.root.join("docs/ucp/browser.openapi.json").read, content_type: "application/json"
  end
end
