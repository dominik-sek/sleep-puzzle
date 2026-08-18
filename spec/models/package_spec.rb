require 'rails_helper'

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
RSpec.describe Package, type: :model do
  describe "translated fields" do
    it "reads the value for the current locale" do
      package = build_package(name: "Szybka ulga", name_en: "Quick relief")

      expect(I18n.with_locale(:pl) { package.name }).to eq("Szybka ulga")
      expect(I18n.with_locale(:en) { package.name }).to eq("Quick relief")
    end

    it "falls back to the default locale when a translation is missing" do
      package = build_package(name: "Szybka ulga")

      expect(I18n.with_locale(:en) { package.name }).to eq("Szybka ulga")
    end

    it "reports which locales have actually been written" do
      package = build_package(name: "Szybka ulga")

      expect(package.translated?(:name, :pl)).to be(true)
      expect(package.translated?(:name, :en)).to be(false)
    end

    it "does not fall back when reading raw values, so the form can tell them apart" do
      package = build_package(name: "Szybka ulga")

      expect(package.raw_translation(:name, :en)).to be_nil
    end

    it "survives a round trip through the database" do
      package = create_package(name: "Szybka ulga", name_en: "Quick relief")

      expect(I18n.with_locale(:en) { package.reload.name }).to eq("Quick relief")
    end
  end

  describe "translated lists" do
    it "stores an entry per line and drops the blank ones" do
      package = build_package
      package.assign_translation_list(:core, :pl, [ "Konsultacja", "  ", "Plan snu" ])

      expect(package.core).to eq([ "Konsultacja", "Plan snu" ])
    end

    it "reads as an empty array when nothing has been written" do
      expect(build_package.extra).to eq([])
    end

    it "falls back to the default locale like any other field" do
      package = build_package
      package.assign_translation_list(:core, :pl, [ "Konsultacja" ])

      expect(I18n.with_locale(:en) { package.core }).to eq([ "Konsultacja" ])
    end
  end

  describe "validations" do
    it "requires a Paddle price id" do
      package = build_package(paddle_price_id: nil)

      expect(package).not_to be_valid
      expect(package.errors[:paddle_price_id]).to be_present
    end

    it "requires a name in the default locale" do
      package = Package.new(paddle_price_id: "pri_123")

      expect(package).not_to be_valid
      expect(package.errors[:name]).to be_present
    end

    # the other language is optional on purpose: Translatable falls back
    it "accepts a package written only in Polish" do
      expect(build_package(name: "Szybka ulga")).to be_valid
    end

    it "rejects a duration that is not a positive whole number" do
      expect(build_package(duration: 0)).not_to be_valid
      expect(build_package(duration: 4)).to be_valid
      expect(build_package(duration: nil)).to be_valid
    end
  end

  describe "scopes" do
    it "lists published packages in position order" do
      second = create_package(name: "Drugi", position: 2)
      first = create_package(name: "Pierwszy", position: 1)
      create_package(name: "Ukryty", position: 0, published: false)

      expect(Package.published.ordered).to eq([ first, second ])
    end
  end

  describe "bookings" do
    it "refuses to be deleted once something has been booked against it" do
      package = create_package
      user = User.create!(email: "customer@example.com", password: "password123")
      Booking.create!(
        name: "Anna", email: "anna@example.com", starts_at: 3.days.from_now,
        status: :confirmed, package: package, user: user
      )

      expect(package.destroy).to be(false)
      expect(package.errors[:base]).to be_present
    end
  end
end
