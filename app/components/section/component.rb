# frozen_string_literal: true

module Section
  class Component < ViewComponent::Base
    attr_reader :title, :subtitle, :heading_level

    # The title is a real heading, not a styled span: `text-t1` is the largest
    # type on any page it appears on, and markup that says otherwise fails
    # WCAG 1.3.1. Defaults to h2 because most sections sit under a page title;
    # the one section that *is* the page title passes `heading_level: :h1`.
    HEADING_LEVELS = %i[h1 h2 h3].freeze

    renders_one :actions

    def initialize(background: :ink,
                   width: :wide,
                   title: nil,
                   subtitle: nil,
                   align: :center,
                   padding: :default,
                   heading_level: :h2
                   )
      @background = background
      @width = width
      @title = title
      @subtitle = subtitle
      @align = align
      @padding = padding
      @heading_level = HEADING_LEVELS.include?(heading_level) ? heading_level : :h2
    end

    def wrapper_classes
      [
        background_classes,
        align_classes,
        border_classes,
        "w-full"
      ].compact.reject(&:empty?).join(" ")
    end

    def padding_classes
      case @padding
      when :compact then "section-padding-compact"
      when :none then "section-padding-none"
      else "section-padding"
      end
    end

    # Derived from the background rather than passed in: only the alternating
    # ink_soft band is edged, and it always is. There is no call site that wants
    # an ink band with rules or a soft band without them.
    def border_classes
      case @background
      when :ink_soft then "border border-x-0 border-border-strong"
      else "border-0"
      end
    end

    def background_classes
      case @background
      when :ink then "bg-ink"
      when :ink_soft then "bg-ink-soft"
      when :surface then "bg-surface"
      else "bg-ink"
      end
    end

    def align_classes
      case @align
      when :center then "text-center"
      when :right then "text-right"
      when :left then "text-left"
      end
    end

    def align_items_classes
      case @align
      when :center then "items-center"
      when :right then "items-end"
      when :left then "items-start"
      end
    end
  end
end
