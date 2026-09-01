# A catalogue item sold through Paddle: a consultation package, an audio product.
#
# Both are created in the admin panel, both carry bilingual copy, both are put in
# an order and shown on the public site, and both are checked out by handing
# Paddle a price id. That shared shape lives here so the two models only have to
# declare what actually differs between them.
#
# The price id is not stored copy - it is the join to Paddle, which owns the
# money. Nothing in this app stores an amount; the price is read back from Paddle
# against this id (see PaddlePriceCatalogService).
module Purchasable
  extend ActiveSupport::Concern

  included do
    include Translatable

    validates :paddle_price_id, presence: true
    validate :name_in_default_locale

    scope :published, -> { where(published: true) }
    scope :ordered, -> { order(:position, :id) }
  end

  private

  # The other locale may be left empty - Translatable falls back to this one -
  # but something has to be fillable back, or the record renders as a blank card.
  def name_in_default_locale
    return if translated?(:name, I18n.default_locale)

    errors.add(:name, :blank)
  end
end
