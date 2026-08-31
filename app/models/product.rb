# == Schema Information
#
# Table name: products
#
#  id                 :bigint           not null, primary key
#  audio_upload_error :string
#  category           :integer
#  cdn_path           :string
#  icon               :string
#  kind               :integer
#  length_minutes     :integer
#  position           :integer          default(0), not null
#  preview_cdn_path   :string
#  published          :boolean          default(FALSE), not null
#  translations       :jsonb            not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  paddle_price_id    :string
#
class Product < ApplicationRecord
  include Purchasable

  # restrict_with_error rather than destroy: an order is a record of what someone
  # paid for, so deleting a bought product would rewrite their history. The panel
  # unpublishes instead.
  has_many :order_items, dependent: :restrict_with_error

  # Where a recording waits between the admin pressing save and Bunny having it.
  # Nothing streams from here; ProductAudioUploadJob purges it once `cdn_path` is
  # set.
  has_one_attached :audio_upload

  # One stream for the whole catalogue rather than one per product: the index
  # would otherwise open a subscription per row, and an upload result has to
  # reach whichever product page the owner happens to be on.
  ADMIN_STREAM = "admin_products"

  # The two things the shop sells, named after how the site talks about them:
  # guided audio for the parent, bedtime stories for the child.
  #
  # `category` is deliberately not an enum yet — it is an unused column with no
  # settled meaning, and declaring one would invent that meaning here.
  # validate: true so a value outside the two becomes a validation error rather
  # than an ArgumentError — the form is a select, but a stale or forged one
  # should re-render the page, not raise
  enum :kind, { audio_process: 0, bedtime_story: 1 }, validate: true

  # Rendered on the shop, the product page, the cart and the dashboard, so it has
  # to follow the reader's language — a frozen Hash of Polish strings showed
  # "Audioproces" on every English page.
  def self.kind_label(kind)
    I18n.t("products.kinds.#{kind}", default: kind.to_s)
  end

  # [label, value] pairs for the admin's rodzaj select.
  def self.kind_options
    kinds.keys.map { |kind| [ kind_label(kind), kind ] }
  end

  # Only what a product without its own emoji falls back to. The design gives
  # each one a distinct icon, so `icon` is the real source and this exists so a
  # newly added product never renders an empty tile.
  KIND_ICONS = {
    "audio_process" => "🌙",
    "bedtime_story" => "🧸"
  }.freeze

  # `long_description` is the "O tym nagraniu" prose on the product page, and
  # `includes` the "Co dostajesz" bullets beside it — the same shape as a
  # package's `core`, so the admin's one-bullet-per-line editor already handles it.
  translates :name, :description, :long_description, lists: %i[includes]

  # The file is the thing being sold, so a product with none cannot go on sale.
  # Two layers, because a validation alone only covers rows saved from now on:
  # this refuses the publish, and the scope below keeps anything already marked
  # published — or published straight through SQL — out of the shop.
  #
  # A recording on its way counts as having one, so a product can be published in
  # the same save as its upload; the scope below still waits for `cdn_path`.
  validates :cdn_path, presence: true, if: -> { published? && !audio_upload_pending? }

  # Overrides Purchasable's, which Package still uses unchanged: a consultation
  # has no file to deliver, so `published` means exactly what it says there.
  # [nil, ""] because the admin form posts an empty string for an untouched
  # field, and normalize_cdn_path leaves a blank one alone.
  scope :published, -> { where(published: true).where.not(cdn_path: [ nil, "" ]) }

  validates :kind, presence: true
  validates :length_minutes, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  # Restricted to characters that survive a URL untouched. Bunny signs the path
  # as it appears in the URL, so a name needing percent-encoding would be signed
  # in one form and requested in another, and every play would 403. Keeping the
  # filenames plain is far easier to live with than encoding both sides.
  validates :cdn_path,
            format: { with: %r{\A/[a-zA-Z0-9/._-]+\z}, message: :invalid },
            allow_blank: true

  # BunnyStorageService always hands back a leading slash, but the admin form falls
  # back to a typed path when the storage zone is unconfigured, and that may or may
  # not have one.
  before_validation :normalize_cdn_path

  def kind_label
    self.class.kind_label(kind)
  end

  def display_icon
    icon.presence || KIND_ICONS.fetch(kind, "🎧")
  end

  # nil when the owner has not filled it in, so the product page can leave the
  # whole "Długość" slot out rather than printing a unit with no number
  def length_label
    return if length_minutes.blank?

    I18n.t("products.length_minutes", count: length_minutes)
  end

  # Whether a buyer can be given a player for this. False for a product whose
  # audio has not been uploaded yet, and false everywhere the CDN is unconfigured
  # — development and the test suite — so those render the library exactly as
  # they did before the CDN existed rather than a control that 404s.
  def streamable?
    cdn_path.present? && BunnySignedUrlService.configured?
  end

  # Whether the shop can let someone hear thirty seconds before paying. Same two
  # conditions as streamable?, against the preview's own path: older products
  # uploaded before previews existed have none, and the page simply omits the
  # player rather than offering a control that 404s.
  def previewable?
    preview_cdn_path.present? && BunnySignedUrlService.configured?
  end

  # The attachment is the whole state — purged on success and on final failure
  # alike, so no status column can be left stale by a worker that died.
  def audio_upload_pending?
    audio_upload.attached?
  end

  # `audio_upload_error` outlives the attachment: it is all that is left to show.
  def audio_upload_failed?
    audio_upload_error.present? && !audio_upload_pending?
  end

  private

  def normalize_cdn_path
    return if cdn_path.blank?

    self.cdn_path = cdn_path.strip
    self.cdn_path = "/#{cdn_path}" unless cdn_path.start_with?("/")
  end
end
