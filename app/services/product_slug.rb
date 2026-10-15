# The same allocator is used when creating products and backfilling the catalogue.
# Read stored translations explicitly so the current request's locale cannot
# change a product's permanent address.
class ProductSlug
  def self.generate(translations, taken:)
    names = (translations || {}).fetch("name", {})
    base = (names["pl"].presence || names["en"]).to_s.tr("_", " ").parameterize(locale: :pl).presence || "product"
    candidate = base
    suffix = 2

    while taken.call(candidate)
      candidate = "#{base}-#{suffix}"
      suffix += 1
    end

    candidate
  end
end
