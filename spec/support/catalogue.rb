# Packages and products carry their copy in a jsonb store, so building one takes
# a couple of steps rather than a single create!. These keep that out of the specs.
module CatalogueHelpers
  def build_package(name: "Konsultacja", name_en: nil, **attributes)
    Package.new({ paddle_price_id: "pri_123", published: true }.merge(attributes)).tap do |package|
      package.assign_translation(:name, :pl, name)
      package.assign_translation(:name, :en, name_en) if name_en
    end
  end

  def create_package(**attributes)
    build_package(**attributes).tap(&:save!)
  end

  def build_product(name: "Bajka o sowie", name_en: nil, description: nil,
                    long_description: nil, includes: nil, **attributes)
    # A published product needs a file: that is what it sells. Specs about the
    # no-audio case pass `cdn_path: nil` (and `published: false` with it, since
    # the two cannot both hold).
    defaults = { paddle_price_id: "pri_456", kind: :bedtime_story, published: true,
                 cdn_path: "/bajki/o-sowie-3f9a1c04.mp3" }

    Product.new(defaults.merge(attributes)).tap do |product|
      product.assign_translation(:name, :pl, name)
      product.assign_translation(:name, :en, name_en) if name_en
      product.assign_translation(:description, :pl, description) if description
      product.assign_translation(:long_description, :pl, long_description) if long_description
      product.assign_translation_list(:includes, :pl, includes) if includes
    end
  end

  def create_product(**attributes)
    build_product(**attributes).tap(&:save!)
  end

  def paddle_price(id: "pri_123", product_name: "Pakiet", description: "Jednorazowo", amount: "24900", currency: "PLN")
    PaddlePriceCatalogService::Price.new(
      id: id, description: description, product_name: product_name, amount: amount, currency: currency
    )
  end
end

RSpec.configure do |config|
  config.include CatalogueHelpers
end
