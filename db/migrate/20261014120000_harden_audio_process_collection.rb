class HardenAudioProcessCollection < ActiveRecord::Migration[8.1]
  class ProductRecord < ActiveRecord::Base
    self.table_name = "products"
  end

  class Block < ActiveRecord::Base
    self.table_name = "content_blocks"
  end

  def up
    # This specific offer advertises 24 recordings. One uploaded introduction
    # was incorrectly declared to be the complete program. Preserve other
    # products and any count the owner has since corrected explicitly.
    ProductRecord.where(id: 2, kind: 0, expected_chapter_count: 1)
      .where("translations -> 'name' ->> 'pl' = ?", '"Idż juz spać" - audioproces')
      .update_all(expected_chapter_count: 24, updated_at: Time.current)

    # Only replace shipped plain-text defaults; owner-written titles survive.
    {
      "audio_landing.hero.title" => {
        pl: [ "Audioproces", "Audioprocesy" ],
        en: [ "Audio process", "Audio processes" ]
      },
      "audio_landing.hero.empty" => {
        pl: [ "Audioproces pojawi się tutaj wkrótce.", "Audioprocesy pojawią się tutaj wkrótce." ],
        en: [ "The audio process will appear here soon.", "Audio processes will appear here soon." ]
      }
    }.each do |key, translations|
      translations.each do |locale, (before, after)|
        column = "value_#{locale}"
        Block.where(key: key, column => before).update_all(column => after, updated_at: Time.current)
      end
    end
  end

  def down
    # Reinstating a count of one would re-enable an incomplete offer for sale.
    raise ActiveRecord::IrreversibleMigration, "Do not restore the incorrect one-chapter declaration"
  end
end
