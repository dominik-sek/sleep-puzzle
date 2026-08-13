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

  private

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
