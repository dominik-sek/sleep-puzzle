class PageMarkdown
  def self.call(html)
    document = Nokogiri::HTML(html)
    document.css("body > header, body > footer").remove
    content = document.at_css("main") || document.at_css("body")
    return "" unless content

    content.css("script, style, noscript, template, svg, nav, iframe, input, select, textarea, [aria-hidden='true']").remove
    ReverseMarkdown.convert(content.to_html, unknown_tags: :bypass, github_flavored: true).strip + "\n"
  end
end
