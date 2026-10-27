# Allocates a URL slug from an article's translated title, the same way
# ProductSlug does for the catalogue. Reads the stored translations explicitly so
# the current request's locale cannot change an article's permanent address.
class ArticleSlug
  def self.generate(translations, taken:)
    titles = (translations || {}).fetch("title", {})
    base = (titles["pl"].presence || titles["en"]).to_s.tr("_", " ").parameterize(locale: :pl).presence || "artykul"
    candidate = base
    suffix = 2

    while taken.call(candidate)
      candidate = "#{base}-#{suffix}"
      suffix += 1
    end

    candidate
  end
end
