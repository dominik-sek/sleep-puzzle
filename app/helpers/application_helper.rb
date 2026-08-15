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

    stored = content_blocks_by_key[key]&.value_for(locale)
    return render_content_block(field, stored) if stored

    # Nothing in the database — a fresh deploy, or a block nobody has filled in.
    # The declared default keeps the page looking finished.
    fallback = field.default_for(locale)
    return render_content_block(field, fallback) if fallback.present?

    missing_content_block(key)
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
