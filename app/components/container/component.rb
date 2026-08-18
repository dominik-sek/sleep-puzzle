# frozen_string_literal: true

module Container
  class Component < ViewComponent::Base
    def initialize(classes: [])
      @classes = classes
    end

    def wrapper_classes
      [
        "section-padding max-w-[1240px] mx-auto w-full",
        @classes
      ].flatten.compact.reject(&:empty?).join(" ")
    end
  end
end
