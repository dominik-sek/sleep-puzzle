class Alert::Component < ViewComponent::Base
  # Colour only. The tone used to be a thick coloured tab down the left edge,
  # which is the callout pattern the design system rules out; it now reads from
  # the title's colour, and the card keeps the same hairline as every other piece.
  TONES = {
    info: "text-accent",
    success: "text-accent-gold",
    warning: "text-accent-terracotta",
    error: "text-accent-coral"
  }.freeze

  def initialize(title:, tone: :info)
    @title = title
    @tone = tone
  end

  private

  def tone_classes
    TONES.fetch(@tone.to_sym, TONES[:info])
  end
end
