# Machine discovery must work without a browser, session, or locale negotiation.
class ApiCatalogController < ActionController::Base
  def index
    response.headers["Link"] = '<https://sleeppuzzle.com/.well-known/api-catalog>; rel="api-catalog"; type="application/linkset+json"'
    render body: Rails.root.join("config/api_catalog.json").read,
           content_type: 'application/linkset+json; profile="https://www.rfc-editor.org/info/rfc9727"'
  end
end
