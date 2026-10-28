module MarkdownNegotiation
  extend ActiveSupport::Concern

  included do
    around_action :negotiate_markdown
  end

  private

  def negotiate_markdown
    return yield unless request.get? || request.head?
    return yield if params[:format].present? && params[:format] != "html"

    markdown = markdown_preferred?
    if markdown
      # Render the same page and run the same authorization callbacks. Setting
      # the cached formats avoids adding .html to every generated URL.
      request.set_header("action_dispatch.request.formats", [ Mime[:html] ])
      self.formats = [ :html ]
    end

    yield

    return unless response.media_type == "text/html"

    vary = response.headers["Vary"].to_s.split(/,\s*/)
    response.headers["Vary"] = (vary + [ "Accept" ]).uniq(&:downcase).join(", ") unless vary.include?("*")
    return unless markdown && response.successful?

    response.body = PageMarkdown.call(response.body)
    response.content_type = "text/markdown; charset=utf-8"
    # These describe the HTML body if a controller set them before conversion.
    %w[Content-Length ETag Last-Modified].each { |header| response.headers.delete(header) }
  end

  def markdown_preferred?
    accepted = Rack::Utils.q_values(request.get_header("HTTP_ACCEPT")).map { |type, quality| [ type.downcase, quality ] }
    markdown_quality = accepted.find { |type, _| type == "text/markdown" }&.last.to_f
    html_quality = accepted.find { |type, _| type == "text/html" }&.last.to_f

    markdown_quality.positive? && markdown_quality >= html_quality
  end
end
