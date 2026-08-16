# Packages carry copy that the site now renders in two languages, so their text
# moves into one jsonb store (see Translatable) and the monolingual columns go.
#
# `core` and `extra` were empty jsonb scaffolding for a package's bullet lists;
# they become translated list fields in the same store rather than a second,
# untranslatable place for copy to live.
#
# Existing rows are Polish — the site has only ever rendered pl — so the backfill
# files them under "pl" and leaves "en" for the owner to fill in.
class MakePackagesTranslatable < ActiveRecord::Migration[8.1]
  def up
    add_column :packages, :translations, :jsonb, default: {}, null: false
    add_column :packages, :position, :integer, default: 0, null: false
    add_column :packages, :published, :boolean, default: false, null: false

    # jsonb_strip_nulls so a package with no for_whom gets {"name": ...} rather
    # than a "for_whom": null the readers would have to step around
    execute <<~SQL.squish
      UPDATE packages
      SET translations = jsonb_strip_nulls(
        jsonb_build_object(
          'name', CASE WHEN name IS NULL THEN NULL ELSE jsonb_build_object('pl', name) END,
          'for_whom', CASE WHEN for_whom IS NULL THEN NULL ELSE jsonb_build_object('pl', for_whom) END
        )
      )
    SQL

    # everything that exists today was hand-created and is live on the site
    execute "UPDATE packages SET published = TRUE"
    execute "UPDATE packages SET position = id"

    remove_column :packages, :name
    remove_column :packages, :for_whom
    remove_column :packages, :core
    remove_column :packages, :extra
  end

  def down
    add_column :packages, :name, :string
    add_column :packages, :for_whom, :text
    add_column :packages, :core, :jsonb, default: {}
    add_column :packages, :extra, :jsonb, default: {}
    add_index :packages, :core, using: :gin
    add_index :packages, :extra, using: :gin

    execute <<~SQL.squish
      UPDATE packages
      SET name = translations -> 'name' ->> 'pl',
          for_whom = translations -> 'for_whom' ->> 'pl'
    SQL

    remove_column :packages, :translations
    remove_column :packages, :position
    remove_column :packages, :published
  end
end
