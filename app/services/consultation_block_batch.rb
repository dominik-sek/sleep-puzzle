# One admin submission, persisted atomically under the same lock as reservations.
class ConsultationBlockBatch
  include ActiveModel::Model

  attr_accessor :dates, :category, :note, :start_time, :end_time
  attr_reader :all_day, :blocks
  validates :category, inclusion: { in: ConsultationBlock::CATEGORIES.keys, message: "wybierz poprawny powód" }
  validate :build_periods

  def initialize(attributes = {})
    @blocks = []
    super({ dates: [], all_day: true, category: "time_off" }.merge(attributes.to_h.symbolize_keys))
  end

  def all_day=(value)
    @all_day = ActiveModel::Type::Boolean.new.cast(value)
  end

  def save
    return false unless valid?
    ConsultationSetting.current.with_lock { blocks.each(&:save!) }
    true
  rescue ActiveRecord::RecordInvalid => error
    errors.add(:base, "Nie zapisano żadnej blokady: #{error.record.errors.full_messages.join(', ')}")
    false
  end

  def conflicting_bookings
    blocks.flat_map { |block| block.conflicting_bookings.to_a }.uniq(&:id)
  end

  private

  def build_periods
    @blocks = []
    selected = Array(dates).map do |value|
      raise Date::Error unless value.to_s.match?(/\A\d{4}-\d{2}-\d{2}\z/)
      Date.iso8601(value.to_s)
    end.uniq.sort
    if selected.empty?
      errors.add(:base, "Zaznacz co najmniej jeden dzień.")
      return
    end
    self.dates = selected.map(&:iso8601)
    if all_day
      ranges = []
      selected.each do |date|
        if ranges.last && ranges.last.last + 1 == date
          ranges.last[1] = date
        else
          ranges << [ date, date ]
        end
      end
      @blocks = ranges.map { |first, last| block(first.beginning_of_day, (last + 1).beginning_of_day) }
    else
      unless valid_time?(start_time) && valid_time?(end_time) && end_time > start_time
        errors.add(:base, "Podaj godziny w obrębie jednego dnia. Koniec musi być później niż początek.")
        return
      end
      @blocks = selected.map do |date|
        from = Time.zone.parse("#{date} #{start_time}")
        to = Time.zone.parse("#{date} #{end_time}")
        if from.strftime("%H:%M") != start_time || to.strftime("%H:%M") != end_time
          errors.add(:base, "Wybrane godziny nie istnieją #{I18n.l(date)} z powodu zmiany czasu.")
        end
        block(from, to)
      end
    end
    @blocks.each do |record|
      errors.add(:base, record.errors.full_messages.join(", ")) unless record.valid?
    end
  rescue Date::Error
    errors.add(:base, "Wybierz poprawne daty.")
  end

  def valid_time?(value)
    value.to_s.match?(/\A(?:[01]\d|2[0-3]):[0-5]\d\z/)
  end

  def block(from, to)
    ConsultationBlock.new(starts_at: from, ends_at: to, all_day: all_day, category: category, note: note)
  end
end
