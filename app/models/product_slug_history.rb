# Every address ever assigned to a product, including its current address. Keeping
# them in one unique index prevents an old link from being claimed by another item.
# == Schema Information
#
# Table name: product_slug_histories
#
#  id         :bigint           not null, primary key
#  slug       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  product_id :bigint           not null
#
# Indexes
#
#  index_product_slug_histories_on_product_id  (product_id)
#  index_product_slug_histories_on_slug        (slug) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (product_id => products.id)
#
class ProductSlugHistory < ApplicationRecord
  belongs_to :product

  attr_readonly :product_id, :slug
  validates :slug, presence: true, uniqueness: true
end
