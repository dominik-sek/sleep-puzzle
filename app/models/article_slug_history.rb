# Every address ever assigned to an article, including its current one. Keeping
# them in one unique index prevents an old link from being claimed by another
# article after a rename.
# == Schema Information
#
# Table name: article_slug_histories
#
#  id         :bigint           not null, primary key
#  slug       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  article_id :bigint           not null
#
# Indexes
#
#  index_article_slug_histories_on_article_id  (article_id)
#  index_article_slug_histories_on_slug        (slug) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (article_id => articles.id)
#
class ArticleSlugHistory < ApplicationRecord
  belongs_to :article

  attr_readonly :article_id, :slug
  validates :slug, presence: true, uniqueness: true
end
