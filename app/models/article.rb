# A long-form blog article the owner writes in the admin panel and publishes on
# the public site. It is a record with identity (slug, date, published state) and
# a bilingual body, so it uses the same Translatable + Action Text + slug-history
# machinery as the catalogue rather than the content-block CMS, which is for fixed
# page copy.
#
# == Schema Information
#
# Table name: articles
#
#  id           :bigint           not null, primary key
#  published    :boolean          default(FALSE), not null
#  published_at :datetime
#  slug         :string           not null
#  translations :jsonb            not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_articles_on_slug  (slug) UNIQUE
#
class Article < ApplicationRecord
  include Translatable

  translates :title, :excerpt, :meta_title, :meta_description

  has_rich_text :body_pl
  has_rich_text :body_en
  has_one_attached :cover_image

  has_many :slug_histories, class_name: "ArticleSlugHistory", dependent: :destroy

  before_validation :assign_slug, on: :create
  before_validation :stamp_published_at
  after_save :remember_slug, if: :saved_change_to_slug?

  validates :slug, presence: true, uniqueness: true,
                   format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validate :slug_not_reserved
  validate :title_in_default_locale

  # Only what the public site shows. Unpublished is a draft: it exists in the
  # panel and nowhere else. Newest first, with a not-yet-dated article falling
  # back to its creation time so a draft flipped to published still has an order.
  scope :published, -> { where(published: true) }
  scope :newest, -> { order(Arel.sql("COALESCE(published_at, created_at) DESC"), id: :desc) }

  def suggested_slug
    ArticleSlug.generate(translations, taken: ->(candidate) {
      self.class.where.not(id: id).exists?(slug: candidate) ||
        ArticleSlugHistory.where.not(article_id: id).exists?(slug: candidate)
    })
  end

  # The body for the current locale, falling back to Polish so an article that
  # has not been translated yet still reads rather than rendering empty.
  def body(locale = I18n.locale)
    [ locale.to_sym, I18n.default_locale ].uniq.each do |language|
      rich = public_send(:"body_#{language}")
      return rich if rich.body.present?
    end
    nil
  end

  # The editor must use only this language's value; falling back to Polish in an
  # empty English field would silently save the Polish copy as a translation.
  def body_editor_html(locale)
    rich = public_send(:"body_#{locale}")
    rich.body.to_trix_html if rich.body.present?
  end

  # The date shown to readers and used for ordering. A published article that has
  # not been given an explicit date still has its creation time.
  def display_date
    published_at || created_at
  end

  # A rough read length for the meta line, derived from the rendered plain text.
  def reading_minutes
    text = body&.to_plain_text.to_s
    words = text.scan(/[\p{L}\p{N}'-]+/).size
    [ (words / 200.0).ceil, 1 ].max
  end

  private

  def assign_slug
    self.slug = suggested_slug if slug.blank?
  end

  def stamp_published_at
    self.published_at ||= Time.current if published?
  end

  def remember_slug
    slug_histories.find_or_create_by!(slug: slug)
  end

  def slug_not_reserved
    return unless ArticleSlugHistory.where.not(article_id: id).exists?(slug: slug)

    errors.add(:slug, :taken)
  end

  def title_in_default_locale
    return if translated?(:title, I18n.default_locale)

    errors.add(:title, :blank)
  end
end
