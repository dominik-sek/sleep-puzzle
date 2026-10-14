module ProductsHelper
  def product_collection_path(product)
    product.audio_process? ? audio_process_path : stories_path
  end

  # Use whole, owner-written opening paragraphs as the overview. Lists, media,
  # headings and longer prose remain intact in the native disclosure below it.
  def audio_includes_parts(product)
    html = product.includes_content&.to_s
    return [ nil, nil ] if html.blank?

    root = Nokogiri::HTML.fragment(html).at_css(".trix-content")
    return [ html.html_safe, nil ] unless root

    nodes = root.children.to_a
    intro = []
    length = 0
    paragraphs = 0
    nodes.each do |node|
      if node.comment? || (node.text? && node.text.strip.empty?)
        intro << node
        next
      end
      break unless node.element? && %w[p div].include?(node.name)
      break if node.at_css("ul, ol, figure, img, video, audio, h1, h2, h3, h4, h5, h6, div, pre, blockquote")
      break if paragraphs == 2 || length + node.text.length > 320

      intro << node
      length += node.text.length
      paragraphs += 1
    end
    remainder = nodes.drop(intro.size)
    return [ html.html_safe, nil ] if remainder.all? { |node| node.comment? || (node.text.strip.empty? && !node.element?) }

    wrap = ->(parts) { content_tag(:div, safe_join(parts.map { |node| node.to_html.html_safe }), class: "trix-content") }
    [ paragraphs.positive? ? wrap.call(intro) : nil, wrap.call(remainder) ]
  end

  # Paddle owns the money (see Purchasable), so the amount is read back from the
  # price catalogue rather than stored here. Returns nil when Paddle is
  # unreachable or no longer knows the id - callers show the product as
  # unavailable rather than guessing at a number.
  def product_price_label(product)
    PaddlePriceCatalogService.find(product.paddle_price_id)&.formatted_amount
  end
end
