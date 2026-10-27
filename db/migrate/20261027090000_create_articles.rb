class CreateArticles < ActiveRecord::Migration[8.1]
  def change
    create_table :articles do |t|
      t.string :slug, null: false
      t.boolean :published, null: false, default: false
      t.datetime :published_at
      t.jsonb :translations, null: false, default: {}
      t.timestamps
    end
    add_index :articles, :slug, unique: true

    # Every address ever assigned to an article, current and previous. Keeping them
    # in one unique index prevents an old link from being claimed by another article,
    # the same way products guard their slugs.
    create_table :article_slug_histories do |t|
      t.references :article, null: false, foreign_key: true
      t.string :slug, null: false
      t.timestamps
    end
    add_index :article_slug_histories, :slug, unique: true
  end
end
