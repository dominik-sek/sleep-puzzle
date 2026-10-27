# frozen_string_literal: true

module Sidebar
  class Component
    class ItemComponent < ViewComponent::Base
      # @param label [String] The display text for the nav item
      # @param href [String] The link URL
      # @param icon [String] SVG icon HTML (optional)
      # @param shortcut [String] Keyboard shortcut display (e.g., "⌘1")
      # @param active [Boolean] Whether this item is currently active
      # @param disabled [Boolean] Whether this item is disabled
      # @param badge [String] Optional badge text (e.g., count)
      # @param classes [String] Additional CSS classes
      def initialize(label:, href: "#", icon: nil, shortcut: nil, active: false, disabled: false, badge: nil, classes: nil)
        super()
        @label = label
        @href = href
        @icon = icon
        @shortcut = shortcut
        @active = active
        @disabled = disabled
        @badge = badge
        @classes = classes
      end

      def item_classes
        base = "group min-h-11 min-w-11 w-full flex items-center justify-between gap-2 rounded-md focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent px-2 py-1.5 text-left text-sm"
        state_classes = if @disabled
                          "text-taupe-dark cursor-not-allowed opacity-50"
        elsif @active
                          "text-cream bg-ink"
        else
                          "text-taupe hover:bg-ink-soft hover:text-cream focus-visible:bg-ink-soft disabled:cursor-not-allowed disabled:opacity-50"
        end

        [ base, state_classes, @classes ].compact.reject(&:empty?).join(" ")
      end

      def collapsed_item_classes
        base = "flex h-11 w-11 items-center justify-center rounded-lg focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent"
        state_classes = if @disabled
                          "text-taupe-dark cursor-not-allowed opacity-50"
        elsif @active
                          "text-cream bg-ink"
        else
                          "text-taupe hover:bg-ink-soft hover:text-cream focus-visible:bg-ink-soft disabled:opacity-50"
        end

        [ base, state_classes ].join(" ")
      end

      def render?
        @label.present?
      end

      def icon?
        @icon.present?
      end

      def shortcut?
        @shortcut.present?
      end

      def badge?
        @badge.present?
      end

      attr_reader :label, :href, :icon, :shortcut, :active, :disabled, :badge
    end
  end
end
