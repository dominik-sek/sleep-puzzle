# frozen_string_literal: true

module Admin
  # Re-reads the price list from Paddle, for the moment right after a price is
  # created there and the panel is still showing the list from before it existed.
  #
  # Without this the only honest answer to "why is my new price not in the list?"
  # is "wait for the cache", which is indistinguishable from having set the price
  # up wrong in Paddle.
  class PaddlePricesController < BaseController
    def update
      prices = PaddlePriceCatalogService.call(refresh: true)

      redirect_back fallback_location: admin_packages_path, notice: refresh_notice(prices)
    end

    private

    # An empty list means either "Paddle returned nothing" or "the call failed" -
    # the service swallows the error so the forms keep rendering. Neither is worth
    # claiming success over, so the message says what to go and check.
    def refresh_notice(prices)
      return "Paddle nie zwrócił żadnych cen. Sprawdź, czy cena jest aktywna." if prices.empty?

      "Odświeżono ceny z Paddle (#{prices.size})."
    end
  end
end
