require "rails_helper"

RSpec.describe ConsultationBlockBatch do
  it "merges adjacent full days, sorts and deduplicates separate dates" do
    batch = described_class.new(dates: %w[2027-03-05 2027-03-01 2027-03-02 2027-03-01], category: "holiday", note: "Prywatne")
    expect { expect(batch.save).to be true }.to change(ConsultationBlock, :count).by(2)
    expect(batch.dates).to eq(%w[2027-03-01 2027-03-02 2027-03-05])
    expect(batch.blocks.map { |block| [ block.starts_at.to_date, block.ends_at.to_date ] }).to eq([
      [ Date.new(2027, 3, 1), Date.new(2027, 3, 3) ], [ Date.new(2027, 3, 5), Date.new(2027, 3, 6) ]
    ])
    expect(batch.blocks.map(&:note)).to eq([ "Prywatne", "Prywatne" ])
  end

  it "writes the same hours separately on every selected date" do
    batch = described_class.new(dates: %w[2027-03-01 2027-03-02], all_day: "0", start_time: "09:00", end_time: "10:30")
    expect { expect(batch.save).to be true }.to change(ConsultationBlock, :count).by(2)
    expect(batch.blocks.all? { |block| block.starts_at.strftime("%H:%M") == "09:00" && block.ends_at.strftime("%H:%M") == "10:30" && !block.all_day? }).to be true
  end

  it "rolls back every block if a later save fails" do
    counter = 0
    allow_any_instance_of(ConsultationBlock).to receive(:save!).and_wrap_original do |original, *args|
      counter += 1
      if counter == 2
        original.receiver.errors.add(:base, "Błąd zapisu")
        raise ActiveRecord::RecordInvalid, original.receiver
      end
      original.call(*args)
    end
    batch = described_class.new(dates: %w[2027-03-01 2027-03-05])
    expect { expect(batch.save).to be false }.not_to change(ConsultationBlock, :count)
    expect(batch.errors.full_messages.join).to include("Nie zapisano żadnej blokady")
  end

  it "rejects empty and malformed dates without saving valid dates from the same request" do
    [ [], %w[2027-03-01 wrong], %w[2027-02-30] ].each do |dates|
      batch = described_class.new(dates: dates)
      expect { expect(batch.save).to be false }.not_to change(ConsultationBlock, :count)
    end
  end

  it "rejects invalid categories and time ranges" do
    [ { category: "wrong" }, { all_day: false, start_time: "20:00", end_time: "09:00" }, { all_day: false, start_time: "09:00", end_time: "09:00" }, { all_day: false, start_time: "25:00", end_time: "26:00" } ].each do |attrs|
      batch = described_class.new({ dates: [ "2027-03-01" ] }.merge(attrs))
      expect { expect(batch.save).to be false }.not_to change(ConsultationBlock, :count)
    end
  end

  it "blocks whole local days correctly across DST" do
    batch = described_class.new(dates: %w[2027-03-28 2027-03-29])
    expect(batch.save).to be true
    block = batch.blocks.first
    expect(block.ends_at - block.starts_at).to eq(47.hours)
    expect(block.starts_at.hour).to eq(0)
    expect(block.ends_at.hour).to eq(0)
  end

  it "rejects a nonexistent DST hour for the whole batch" do
    batch = described_class.new(dates: %w[2027-03-27 2027-03-28], all_day: false, start_time: "02:30", end_time: "04:00")
    expect { expect(batch.save).to be false }.not_to change(ConsultationBlock, :count)
    expect(batch.errors.full_messages.join).to include("zmiany czasu")
  end

  it "preserves active bookings and returns unique conflicts" do
    user = User.create!(email: "batch@example.com", password: "password123")
    booking = Booking.create!(user: user, package: create_package, name: "Marta", email: user.email, starts_at: Time.zone.parse("2027-03-01 08:15"), status: :confirmed)
    batch = described_class.new(dates: %w[2027-03-01 2027-03-02])
    expect(batch.save).to be true
    expect(batch.conflicting_bookings).to eq([ booking ])
    expect(booking.reload).to be_confirmed
  end
end
