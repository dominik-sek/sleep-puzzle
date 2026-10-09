# frozen_string_literal: true

module Admin::ContentBlocksHelper
  # The preview uses the real public routes. Some blocks describe a state or a
  # card that only appears when matching data exists; those still open their
  # parent page so the owner can inspect the surrounding layout.
  def content_preview_path(page_key, locale:)
    options = { locale: (locale == :en ? :en : nil) }

    case page_key
    when "home", "footer", "testimonials" then root_path(**options)
    when "packages" then packages_path(**options)
    when "audio_landing" then audio_process_path(**options)
    when "about" then about_path(**options)
    when "bookings" then bookings_path(**options)
    when "shop" then products_path(**options)
    when "cart" then cart_path(**options)
    when "dashboard" then dashboard_index_path(**options)
    when "refunds" then refunds_path(**options)
    when "terms" then terms_path(**options)
    when "contact" then contact_path(**options)
    end
  end
end
