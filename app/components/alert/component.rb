class Alert::Component < ViewComponent::Base
  TONES = {
    info: "border-l-accent text-accent",
    success: "border-l-accent-gold text-accent-gold",
    warning: "border-l-accent-terracotta text-accent-terracotta",
    error: "border-l-accent-coral text-accent-coral"
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
