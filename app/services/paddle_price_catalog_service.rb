# The active prices in the Paddle account, for the admin's price picker.
#
# A package or product is joined to Paddle by a price id, and that id is the one
# thing on the form nobody can eyeball for correctness: `pri_01j9k...` looks the
# same whether it is right or a typo, and a wrong one only surfaces when a buyer
# reaches a broken checkout. So the panel offers the account's real prices as a
# list instead of a text field.
#
# Paddle owns the money: no amount is stored here, it is read back from this
# catalogue whenever a price has to be shown next to a record.
#
# The Paddle client is configured by Pay (see Pay::PaddleBilling), so this only
# has to make the call.
class PaddlePriceCatalogService < ApplicationService
  CACHE_KEY = "paddle/price_catalog"

  # Short on purpose. The cache is not here to save API calls - a request already
  # fetches the list once and hands it to every row - it is here so a slow or
  # unreachable Paddle cannot make every admin page render wait on it. A minute
  # buys that without the panel showing a catalogue the owner has already changed.
  # Admin::PaddlePricesController#update clears it on demand.
  CACHE_TTL = 1.minute

  # https://developer.paddle.com/concepts/pricing/currencies
  ZERO_DECIMAL_CURRENCIES = %w[JPY KRW TWD].freeze

  Price = Struct.new(:id, :description, :product_name, :amount, :currency, keyword_init: true) do
    # "Pakiet Szybka ulga - Jednorazowo - 249.00 PLN"
    def label
      [ product_name, description, formatted_amount ].compact_blank.join(" - ")
    end

    # Paddle sends minor units as a string ("24900"). Currencies with no minor
    # unit are listed rather than assumed, because dividing a JPY amount by 100
    # would quietly show a price a hundred times too small.
    def formatted_amount
      return if amount.blank? || currency.blank?

      precision = ZERO_DECIMAL_CURRENCIES.include?(currency) ? 0 : 2
      major = amount.to_d / (10**precision)

      # strip_insignificant_zeros: false - the pl locale strips them, and "249,5 PLN"
      # does not read as an amount of money
      ActiveSupport::NumberHelper.number_to_currency(
        major, unit: currency, format: "%n %u", precision: precision,
        strip_insignificant_zeros: false
      )
    end
  end

  # nil for an id Paddle no longer knows about - a price that was archived, or a
  # typo from before the panel offered a list. The admin index shows that as a
  # warning rather than silently rendering a row that cannot be bought.
  def self.find(price_id)
    return if price_id.blank?

    call.find { |price| price.id == price_id }
  end

  def initialize(refresh: false)
    @refresh = refresh
  end

  # Returns [] when Paddle cannot be reached: the admin form still has to render,
  # and the view falls back to a plain text field so a price id can be pasted in
  # rather than the whole page being unusable while Paddle is down.
  def call
    Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL, force: @refresh) { fetch_prices }
  rescue Paddle::Error, Paddle::ErrorGenerator, Faraday::Error => e
    Rails.logger.error("[paddle] could not load the price catalogue: #{e.message}")
    []
  end

  private

  def fetch_prices
    Paddle::Price.list(status: "active", include: "product", per_page: 200).map do |price|
      Price.new(
        id: price.id,
        description: price.description,
        product_name: price.product&.name,
        amount: price.unit_price&.amount,
        currency: price.unit_price&.currency_code
      )
    end
  end
end
