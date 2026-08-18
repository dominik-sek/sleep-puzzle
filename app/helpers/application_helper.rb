module ApplicationHelper
  ICON_ROOT = Rails.root.join("app/assets/icons")

  ICON_CACHE = Concurrent::Map.new

  ICON_ATTRS = {
    xmlns: "http://www.w3.org/2000/svg",
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: "currentColor",
    "stroke-width": "2",
    "stroke-linecap": "round",
    "stroke-linejoin": "round",
    "aria-hidden": "true"
  }.freeze

  # @param name [String, Symbol] icon file name, e.g. "chevron-down"
  # @param size [Integer] sets width/height; omit to size with CSS classes instead
  # @param options [Hash] any other key becomes an SVG attribute (class:, data:, ...)
  def icon(name, size: nil, **options)
    options = options.merge(width: size, height: size) if size
    content_tag(:svg, icon_markup(name), ICON_ATTRS.merge(options))
  end

  # Renders an editable block from the CMS by its key. Blocks are loaded once per
  # request and memoised, so a page using several of them still costs one query
  # rather than one each.
  #
  # An unknown key raises in development and test — a typo should surface at once
  # rather than quietly render nothing — and is ignored in production, where a
  # missing block must never take a page down.
  def content_block(key, locale: I18n.locale)
    field = ContentBlock::Registry.field(key)

    unless field
      raise ArgumentError, "Unknown content block #{key.inspect}" if Rails.env.local?

      return
    end

    # an image block has no text to render; content_image is the way in
    if field.image?
      raise ArgumentError, "#{key.inspect} is an image block; use content_image" if Rails.env.local?

      return
    end

    stored = content_blocks_by_key[key]&.value_for(locale)
    return render_content_block(field, stored) if stored

    # Nothing in the database — a fresh deploy, or a block nobody has filled in.
    # The declared default keeps the page looking finished.
    fallback = field.default_for(locale)
    return render_content_block(field, fallback) if fallback.present?

    missing_content_block(key)
  end

  # An uploaded picture from the CMS, e.g. content_image("home.about.photo").
  #
  # Returns nil when nothing has been uploaded yet — unlike a text block there is
  # no default to fall back to, so the template decides what an empty slot looks
  # like rather than this rendering a broken <img>.
  #
  # Served as a resized variant: the owner uploads whatever came off their phone,
  # and the page should not carry a 4000px original.
  def content_image(key, resize_to: [ 1200, 1200 ], **options)
    field = ContentBlock::Registry.field(key)

    unless field&.image?
      raise ArgumentError, "#{key.inspect} is not an image content block" if Rails.env.local?

      return
    end

    block = content_blocks_by_key[key]
    return unless block&.image&.attached?

    image_tag block.image.variant(resize_to_limit: resize_to), **options
  end

  # A URL typed into the CMS, for a block whose value is a link target.
  #
  # Anything that is not an ordinary web address falls back to "#": the panel is
  # admin-only, so this is less about attack than about a mistyped value ending up
  # in an href and doing something surprising.
  def content_link_url(key, fallback: "#")
    safe_link_url(content_block(key), fallback: fallback)
  end

  # The same check for a URL that did not come from a block of its own — a field
  # on a collection item, say, which content_link_url has no key to look up.
  def safe_link_url(value, fallback: "#")
    value = value.to_s.strip
    return fallback if value.blank?
    return value if value.start_with?("/", "#")
    return value if value.match?(%r{\A(https?://|mailto:)}i)

    fallback
  end

  # The owner-managed list for a section, e.g. content_items("home.process").
  # Returns an array of { field_key => value } hashes in display order, falling
  # back to the collection's declared defaults when the database has none — so a
  # fresh deploy renders a populated list like the rest of the page.
  def content_items(section_key, locale: I18n.locale)
    collection = ContentBlock::Registry.collection(section_key)

    unless collection
      raise ArgumentError, "No collection declared for #{section_key.inspect}" if Rails.env.local?

      return []
    end

    stored = content_items_by_collection[section_key]
    return stored.map { |item| item.to_values(locale) } if stored.present?

    collection.default_items(locale)
  end

  private

  def content_items_by_collection
    @content_items_by_collection ||= ContentItem.declared.order(:position, :id).group_by(&:collection_key)
  end

  def content_blocks_by_key
    @content_blocks_by_key ||= ContentBlock.declared.with_bodies.index_by(&:key)
  end

  # Stored rich text renders its own <div class="trix-content"> wrapper; a
  # default out of the yaml is a bare String, so it gets the same wrapper here.
  # Otherwise the page would be styled differently before and after the first
  # edit. The yaml is developer-authored, not user input, so it is trusted.
  def render_content_block(field, value)
    return value unless field.rich?
    return value if value.is_a?(ActionText::RichText)

    tag.div(value.to_s.html_safe, class: "trix-content")
  end

  # Loud in development so an unfilled block is obvious while building pages;
  # silent in production, where a gap beats shouting at visitors.
  def missing_content_block(key)
    return unless Rails.env.local?

    tag.span("[brak treści: #{key}]",
             class: "rounded bg-red-500/15 px-2 py-1 text-t6 text-red-300")
  end

  def icon_markup(name)
    markup =
      if Rails.env.local?
        read_icon(name)
      else
        ICON_CACHE.fetch_or_store(name.to_s) { read_icon(name) }
      end

    markup.html_safe
  end

  def read_icon(name)
    path = ICON_ROOT.join("#{name}.svg")
    raise ArgumentError, "Unknown icon #{name}" unless path.exist?

    path.read.strip
  end
end
