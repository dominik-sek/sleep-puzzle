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
    unless ContentBlock::Registry.key?(key)
      raise ArgumentError, "Unknown content block #{key.inspect}" if Rails.env.local?

      return
    end

    value = content_blocks_by_key[key]&.value_for(locale)
    return value if value

    missing_content_block(key)
  end

  private

  def content_blocks_by_key
    @content_blocks_by_key ||= ContentBlock.declared.with_bodies.index_by(&:key)
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
