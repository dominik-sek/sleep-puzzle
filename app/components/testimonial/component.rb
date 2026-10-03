# frozen_string_literal: true

module Testimonial
  class Component < ViewComponent::Base
    VARIANTS = %i[default card centered].freeze
    SIZES = %i[sm md lg].freeze

    # @param quote [String] The testimonial quote text (required)
    # @param author_name [String] The author's name (required)
    # @param author_title [String] The author's job title or role
    # @param author_image [String, ActiveStorage::Attached::One] URL or uploaded avatar
    # @param company [String] The author's company name
    # @param rating [Integer] Star rating (1-5), nil to hide
    # @param variant [Symbol] Display variant: :default, :card, :centered
    # @param size [Symbol] Size variant: :sm, :md, :lg
    # @param show_quote_icon [Boolean] Whether to show the quote icon
    # @param classes [String] Additional CSS classes for the wrapper
    def initialize(
      quote:,
      author_name:,
      author_title: nil,
      author_image: nil,
      company: nil,
      rating: nil,
      variant: :default,
      size: :md,
      show_quote_icon: false,
      classes: nil
    )
      super()
      @quote = quote
      @author_name = author_name
      @author_title = author_title
      @author_image = author_image
      @company = company
      @rating = rating.to_i.clamp(0, 5) if rating.present?
      @variant = VARIANTS.include?(variant) ? variant : :default
      @size = SIZES.include?(size) ? size : :md
      @show_quote_icon = show_quote_icon
      @classes = classes
    end

    def wrapper_classes
      [
        base_classes,
        variant_classes,
        @classes
      ].compact.reject(&:empty?).join(" ")
    end

    def quote_classes
      [
        "m-0 whitespace-pre-line break-words text-cream",
        card? ? "font-semibold leading-[1.65]" : "leading-relaxed",
        quote_size_classes
      ].join(" ")
    end

    def author_name_classes
      [
        "break-words font-bold #{card? ? 'text-cream' : 'text-tan'}",
        author_name_size_classes
      ].join(" ")
    end

    def author_title_classes
      [
        "text-taupe",
        author_title_size_classes
      ].join(" ")
    end

    def avatar_classes
      [
        "rounded-full object-cover",
        avatar_size_classes
      ].join(" ")
    end

    def avatar_wrapper_classes
      [
        "shrink-0 rounded-full bg-ink-soft flex items-center justify-center overflow-hidden",
        avatar_size_classes
      ].join(" ")
    end

    def author_initials
      @author_name.to_s.split(/\s+/).first(2).filter_map { |part| part[0]&.upcase }.join.presence || "?"
    end

    def author_image_source
      @author_image.respond_to?(:variant) ? @author_image.variant(resize_to_fill: [ 112, 112 ]) : @author_image
    end

    def show_rating?
      @rating.present? && @rating.positive?
    end

    def filled_stars
      @rating || 0
    end

    def empty_stars
      5 - filled_stars
    end

    def centered?
      @variant == :centered
    end

    def card?
      @variant == :card
    end

    def author_subtitle
      parts = []
      parts << @author_title if @author_title.present?
      parts << @company if @company.present?
      parts.join(" at ") if parts.any?
    end

    private

    attr_reader :quote, :author_name, :author_title, :author_image, :company,
                :rating, :variant, :size, :show_quote_icon

    def base_classes
      ""
    end

    def variant_classes
      case @variant
      when :card
        "flex h-full min-w-0 flex-col rounded-2xl border border-border-strong bg-surface p-6 shadow-[0_12px_36px_rgba(0,0,0,0.12)] sm:p-7"
      when :centered
        "text-center"
      else # :default
        ""
      end
    end

    def quote_size_classes
      return ({ sm: "text-t6", md: "text-[1.05rem]", lg: "text-t4" }.fetch(@size)) if card?

      case @size
      when :sm then "text-t6"
      when :lg then "text-t4"
      else "text-t5" # :md
      end
    end

    def author_name_size_classes
      case @size
      when :sm then "text-t6"
      when :lg then "text-t5"
      else card? ? "text-base" : "text-t6" # :md
      end
    end

    def author_title_size_classes
      case @size
      when :sm then "text-xs"
      when :lg then "text-base"
      else "text-sm" # :md
      end
    end

    def avatar_size_classes
      case @size
      when :sm then "size-8"
      when :lg then "size-14"
      else card? ? "size-12" : "size-10" # :md
      end
    end
  end
end
