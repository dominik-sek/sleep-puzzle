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

  def build_product(name: "Bajka o sowie", name_en: nil, **attributes)
    Product.new({ paddle_price_id: "pri_456", kind: :bedtime_story, published: true }.merge(attributes)).tap do |product|
      product.assign_translation(:name, :pl, name)
      product.assign_translation(:name, :en, name_en) if name_en
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
