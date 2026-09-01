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
  translates :name, :for_whom, lists: %i[core extra]

  has_many :bookings, dependent: :restrict_with_error

  validates :duration, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
end
