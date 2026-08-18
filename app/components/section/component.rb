# frozen_string_literal: true

module Section
  class Component < ViewComponent::Base
    attr_reader :title, :subtitle

    renders_one :actions

    def initialize(background: :ink,
                   bordered: true,
                   width: :wide,
                   title: nil,
                   subtitle: nil,
                   align: :center,
                   padding: :default,
                   classes: []
                   )
      @background = background
      @bordered = bordered
      @width = width
      @title = title
      @subtitle = subtitle
      @align = align
      @padding = padding
      @classes = classes
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
