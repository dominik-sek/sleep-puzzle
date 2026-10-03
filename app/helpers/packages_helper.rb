module PackagesHelper
  # The same join as ProductsHelper#product_price_label: Paddle owns the money
  # (see Purchasable), so the amount is read back from the price catalogue rather
  # than stored here. Returns nil when Paddle is unreachable or no longer knows
  # the id - the card then shows the package as unavailable and drops its booking
  # button, because a package we cannot price is a package we cannot sell.
  def package_price_label(package)
    PaddlePriceCatalogService.find(package.paddle_price_id)&.formatted_amount
  end

  # The comparison was originally uploaded inside the introduction's rich text.
  # Keep that upload visible below the cards until the owner replaces it through
  # the dedicated comparison image field.
  def package_collaboration_parts
    fragment = Nokogiri::HTML.fragment(content_block("packages.collaboration.body").to_s)
    attachment = fragment.at_css('action-text-attachment[content-type^="image/"]')
    source = attachment && (attachment["url"].presence || attachment.at_css("img")&.[]("src"))
    comparison = if source.present?
      attachment.remove
      { src: source, thumbnail_src: source,
        width: attachment["width"].to_i, height: attachment["height"].to_i }
    end

    [ fragment.to_html.html_safe, comparison ]
  end

  def package_comparison_image(embedded_comparison)
    block = content_blocks_by_key["packages.comparison.image"]
    return embedded_comparison unless block&.image&.attached?

    blob = block.image.blob
    {
      src: url_for(block.image),
      thumbnail_src: url_for(block.image.variant(resize_to_limit: [ 800, 1100 ])),
      width: blob.metadata["width"].to_i,
      height: blob.metadata["height"].to_i
    }
  end
end
