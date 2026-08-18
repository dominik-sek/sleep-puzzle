# frozen_string_literal: true

module Sidebar
  class Component
    class SectionItemComponent < ViewComponent::Base
      # @param label [String] The display text for the section item
      # @param href [String] The link URL
      # @param icon [String] SVG icon HTML (optional)
      # @param badge [String] Optional badge text (e.g., count, price)
      # @param active [Boolean] Whether this item is currently active
      # @param disabled [Boolean] Whether this item is disabled
      # @param classes [String] Additional CSS classes
      def initialize(label:, href: "#", icon: nil, badge: nil, active: false, disabled: false, classes: nil)
        super()
        @label = label
        @href = href
        @icon = icon
        @badge = badge
        @active = active
        @disabled = disabled
        @classes = classes
      end

      def item_classes
        base = "w-full flex items-center justify-between gap-2 rounded-md pl-2 pr-9 py-1.5 text-left text-sm"
        state_classes = if @disabled
                          "text-taupe-dark cursor-not-allowed opacity-50"
                        elsif @active
                          "text-cream bg-ink"
                        else
                          "text-taupe hover:bg-ink-soft hover:text-cream focus-visible:bg-ink-soft focus:outline-hidden disabled:cursor-not-allowed disabled:opacity-50"
                        end

        [base, state_classes, @classes].compact.reject(&:empty?).join(" ")
      end

      def render?
        @label.present?
      end

      def icon?
        @icon.present?
      end

      def badge?
        @badge.present?
      end

      attr_reader :label, :href, :icon, :badge, :active, :disabled
    end
  end
end
