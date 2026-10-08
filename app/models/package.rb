# == Schema Information
#
# Table name: packages
#
#  id              :bigint           not null, primary key
#  duration        :integer
#  position        :integer          default(0), not null
#  published       :boolean          default(FALSE), not null
#  translations    :jsonb            not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  paddle_price_id :string
#
class Package < ApplicationRecord
  include Purchasable

  # `core` and `extra` are bullet lists - the "Co otrzymujecie" benefits and the
  # add-ons beneath them on the packages page. They were empty jsonb columns
  # before the copy became bilingual; keeping them in the same store means there
  # is one place a package's words live, rather than one translatable place and
  # one that is not.
  CARD_SUMMARY_MAX_LENGTH = 220
  CARD_HIGHLIGHTS_LIMIT = 5
  CARD_HIGHLIGHT_MAX_LENGTH = 140

  translates :name, :for_whom, :organization, lists: %i[highlights core extra]

  # Keep legacy paragraphs available in the details rather than clipping them
  # into a sentence that might omit a condition of the offer.
  def card_summary
    for_whom if for_whom.to_s.length <= CARD_SUMMARY_MAX_LENGTH
  end

  def card_highlights
    highlights.first(CARD_HIGHLIGHTS_LIMIT)
  end

  has_many :bookings, dependent: :restrict_with_error

  validates :duration, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
end
