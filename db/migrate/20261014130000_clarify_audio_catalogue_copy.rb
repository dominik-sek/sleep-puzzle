class ClarifyAudioCatalogueCopy < ActiveRecord::Migration[8.1]
  class Block < ActiveRecord::Base
    self.table_name = "content_blocks"
  end

  COPY = {
    pl: [ "Masz już u mnie zakupy? Zaloguj się, żeby zobaczyć swoje nagrania.", "Kupione nagrania znajdziesz w swoim koncie." ],
    en: [ "Bought here before? Sign in to see your recordings.", "Your purchased recordings are in your account." ]
  }.freeze

  def up
    replace_copy
  end

  def down
    replace_copy(reverse: true)
  end

  private

  def replace_copy(reverse: false)
    COPY.each do |locale, values|
      before, after = reverse ? values.reverse : values
      column = "value_#{locale}"
      Block.where(key: "shop.hero.returning", column => before)
        .update_all(column => after, updated_at: Time.current)
    end
  end
end
