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
        "w-full py-8 px-8"
      ].compact.reject(&:empty?).join(" ")
      # bordered, width, background, align, padding
    end

    def border_classes
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
  end
end
