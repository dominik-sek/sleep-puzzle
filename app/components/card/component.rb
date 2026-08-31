# frozen_string_literal: true

module Card
  class Component < ViewComponent::Base
    VARIANTS = %i[default elevated well].freeze
    PADDINGS = %i[none sm md lg].freeze
    SHADOWS = %i[none xs sm md lg xl].freeze
    ROUNDED = %i[none sm md lg xl 2xl full].freeze

    renders_one :header
    renders_one :body
    renders_one :footer
    renders_one :image, lambda { |src:, alt: "", position: :top, aspect: nil, classes: nil|
      ImageComponent.new(src: src, alt: alt, position: position, aspect: aspect, classes: classes)
    }

    # @param variant [Symbol] Style variant: :default, :elevated, :well
    # @param padding [Symbol] Content padding: :none, :sm, :md, :lg
    # @param shadow [Symbol] Shadow size: :none (default), :xs, :sm, :md, :lg, :xl.
    #   Flat by default: DESIGN.md's Flat Page Rule reserves shadow for things that
    #   genuinely float above the page (the payment overlay on the booking
    #   calendar). An in-page card raises its tone or firms its border instead.
    # @param rounded [Symbol] Border radius: :none, :sm, :md, :lg, :xl, :"2xl", :full
    # @param border [Boolean] Show border
    # @param hoverable [Boolean] Add hover effects
    # @param clickable [Boolean] Make entire card clickable (adds cursor and hover)
    # @param divide [Boolean] Add dividers between header, body, footer
    # @param full_width_mobile [Boolean] Edge-to-edge on mobile
    # @param classes [String] Additional CSS classes
    def initialize(
      variant: :default,
      padding: :md,
      shadow: :none,
      rounded: :"2xl",
      border: true,
      hoverable: false,
      clickable: false,
      divide: false,
      full_width_mobile: false,
      classes: nil
    )
      super()
      @variant = VARIANTS.include?(variant) ? variant : :default
      @padding = PADDINGS.include?(padding) ? padding : :md
      @shadow = SHADOWS.include?(shadow) ? shadow : :none
      @rounded = ROUNDED.include?(rounded) ? rounded : :"2xl"
      @border = border
      @hoverable = hoverable
      @clickable = clickable
      @divide = divide
      @full_width_mobile = full_width_mobile
      @classes = classes
    end

    def wrapper_classes
      [
        base_classes,
        variant_classes,
        shadow_classes,
        rounded_classes,
        border_classes,
        hover_classes,
        divide_classes,
        @classes
      ].compact.reject(&:empty?).join(" ")
    end

    def header_classes
      [
        header_padding_classes,
        header_background_classes
      ].compact.reject(&:empty?).join(" ")
    end

    def body_classes
      body_padding_classes
    end

    def footer_classes
      [
        footer_padding_classes,
        footer_background_classes
      ].compact.reject(&:empty?).join(" ")
    end

    private

    def base_classes
      "overflow-hidden"
    end

    def variant_classes
      case @variant
      when :well
        "bg-ink-soft"
      else # :default (elevated)
        "bg-surface"
      end
    end

    def shadow_classes
      return "" if @variant == :well

      case @shadow
      when :none then ""
      when :sm then "shadow-sm"
      when :md then "shadow-md"
      when :lg then "shadow-lg"
      when :xl then "shadow-xl"
      when :xs then "shadow-xs"
      else "" # :none
      end
    end

    def rounded_classes
      if @full_width_mobile
        case @rounded
        when :none then ""
        when :sm then "sm:rounded-sm"
        when :md then "sm:rounded-md"
        when :lg then "sm:rounded-lg"
        when :xl then "sm:rounded-xl"
        when :full then "sm:rounded-full"
        else "sm:rounded-2xl" # :2xl
        end
      else
        case @rounded
        when :none then ""
        when :sm then "rounded-sm"
        when :md then "rounded-md"
        when :lg then "rounded-lg"
        when :xl then "rounded-xl"
        when :full then "rounded-full"
        else "rounded-2xl" # :2xl
        end
      end
    end

    def border_classes
      return "" unless @border

      if @full_width_mobile
        "border-y sm:border border-border-strong"
      else
        "border border-border-strong"
      end
    end

    def hover_classes
      return "" unless @hoverable || @clickable

      classes = []
      classes << "transition-all duration-200"
      classes << "hover:border-border-input" if @hoverable
      classes << "cursor-pointer hover:bg-ink-soft" if @clickable
      classes.join(" ")
    end

    def divide_classes
      return "" unless @divide

      "divide-y divide-border"
    end

    def header_padding_classes
      case @padding
      when :none then ""
      when :sm then "px-3 py-3 sm:px-4"
      when :lg then "px-6 py-6 sm:px-8"
      else "px-4 py-5 sm:px-6" # :md
      end
    end

    def header_background_classes
      return "" unless @divide

      "bg-ink-soft border-b border-border-strong"
    end

    def body_padding_classes
      case @padding
      when :none then ""
      when :sm then "px-3 py-3 sm:p-4"
      when :lg then "px-6 py-6 sm:p-8"
      else "px-4 py-5 sm:p-6" # :md
      end
    end

    def footer_padding_classes
      case @padding
      when :none then ""
      when :sm then "px-3 py-3 sm:px-4"
      when :lg then "px-6 py-5 sm:px-8"
      else "px-4 py-4 sm:px-6" # :md
      end
    end

    def footer_background_classes
      "bg-ink-soft"
    end

    attr_reader :variant, :padding, :shadow, :rounded, :border, :hoverable, :clickable, :divide, :full_width_mobile

    # Nested ImageComponent for card images
    class ImageComponent < ViewComponent::Base
      POSITIONS = %i[top bottom].freeze
      ASPECTS = %i[auto square video wide].freeze
      attr_reader :src, :alt, :position

      def initialize(src:, alt: "", position: :top, aspect: nil, classes: nil)
        super()
        @src = src
        @alt = alt
        @position = POSITIONS.include?(position) ? position : :top
        @aspect = aspect
        @classes = classes
      end

      def wrapper_classes
        [
          aspect_classes,
          "bg-ink-soft",
          @classes
        ].compact.reject(&:empty?).join(" ")
      end

      def image_classes
        "w-full h-full object-center object-cover"
      end

      private

      def aspect_classes
        case @aspect
        when :square then "aspect-square"
        when :video then "aspect-video"
        when :wide then "aspect-[21/9]"
        else "" # auto - no fixed aspect
        end
      end
    end
  end
end
