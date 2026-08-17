# == Schema Information
#
# Table name: products
#
#  id              :bigint           not null, primary key
#  category        :integer
#  icon            :string
#  kind            :integer
#  length_minutes  :integer
#  position        :integer          default(0), not null
#  published       :boolean          default(FALSE), not null
#  translations    :jsonb            not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  paddle_price_id :string
#
class Product < ApplicationRecord
  include Purchasable

  # restrict_with_error rather than destroy: an order is a record of what someone
  # paid for, so deleting a bought product would rewrite their history. The panel
  # unpublishes instead.
  has_many :order_items, dependent: :restrict_with_error

  # The two things the shop sells, named after how the site talks about them:
  # guided audio for the parent, bedtime stories for the child.
  #
  # `category` is deliberately not an enum yet — it is an unused column with no
  # settled meaning, and declaring one would invent that meaning here.
  # validate: true so a value outside the two becomes a validation error rather
  # than an ArgumentError — the form is a select, but a stale or forged one
  # should re-render the page, not raise
  enum :kind, { audio_process: 0, bedtime_story: 1 }, validate: true

  KIND_LABELS = {
    "audio_process" => "Audioproces",
    "bedtime_story" => "Bajka na dobranoc"
  }.freeze

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

  validates :kind, presence: true
  validates :length_minutes, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  def kind_label
    KIND_LABELS.fetch(kind, kind)
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
end
