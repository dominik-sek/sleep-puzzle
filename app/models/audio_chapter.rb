# == Schema Information
#
# Table name: audio_chapters
#
#  id               :bigint           not null, primary key
#  cdn_path         :string
#  duration_seconds :integer
#  position         :integer          default(0), not null
#  translations     :jsonb            not null
#  upload_error     :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  product_id       :bigint           not null
#
# Indexes
#
#  index_audio_chapters_on_product_id                      (product_id)
#  index_audio_chapters_on_product_id_and_position_and_id  (product_id,position,id)
#
# Foreign Keys
#
#  fk_rails_...  (product_id => products.id)
#
class AudioChapter < ApplicationRecord
  include Translatable

  belongs_to :product
  has_one_attached :audio_upload
  translates :title

  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :duration_seconds, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :cdn_path, format: { with: %r{\A/[a-zA-Z0-9/._-]+\z} }, allow_blank: true
  validate :audio_process_product
  validate :title_in_default_locale

  before_validation :normalize_cdn_path

  scope :ordered, -> { order(:position, :id) }
  scope :ready, -> { where.not(cdn_path: [ nil, "" ]) }

  def ready?
    cdn_path.present?
  end

  def streamable?
    ready? && BunnySignedUrlService.configured?
  end

  def duration_label
    return if duration_seconds.blank?

    "#{duration_seconds / 60}:#{(duration_seconds % 60).to_s.rjust(2, '0')}"
  end

  private

  def audio_process_product
    errors.add(:product, :invalid) unless product&.audio_process?
  end

  def title_in_default_locale
    errors.add(:title, :blank) unless translated?(:title, I18n.default_locale)
  end

  def normalize_cdn_path
    return if cdn_path.blank?

    self.cdn_path = cdn_path.strip
    self.cdn_path = "/#{cdn_path}" unless cdn_path.start_with?("/")
  end
end
