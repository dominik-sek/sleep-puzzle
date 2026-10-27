# Serves the llms.txt discovery files AI crawlers read: a curated index of the
# key pages (/llms.txt) and the full text of every article (/llms-full.txt). Both
# are first-party plain text - nothing here loads anything into a visitor's
# browser, so the privacy commitment is untouched.
class LlmsController < ApplicationController
  layout false

  def index
    @articles = Article.published.newest
  end

  def full
    @articles = Article.published.newest
  end
end
