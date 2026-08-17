require 'rails_helper'

# == Schema Information
#
# Table name: products
#
#  id              :bigint           not null, primary key
#  category        :integer
#  icon            :string
#  kind            :integer
#  length_minutes  :integer
#  position        :integer          default(0), not null
#  published       :boolean          default(FALSE), not null
#  translations    :jsonb            not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  paddle_price_id :string
#
RSpec.describe Product, type: :model do
  describe "translated fields" do
    it "reads the value for the current locale and falls back to Polish" do
      product = build_product(name: "Bajka o sowie", name_en: "The owl story")
      product.assign_translation(:description, :pl, "Kojąca bajka na dobranoc")

      expect(I18n.with_locale(:en) { product.name }).to eq("The owl story")
      expect(I18n.with_locale(:en) { product.description }).to eq("Kojąca bajka na dobranoc")
    end
  end

  describe "kind" do
    it "is required" do
      expect(build_product(kind: nil)).not_to be_valid
    end

    it "labels the two kinds the shop sells" do
      expect(build_product(kind: :bedtime_story).kind_label).to eq("Bajka na dobranoc")
      expect(build_product(kind: :audio_process).kind_label).to eq("Audioproces")
    end
  end

  describe "validations" do
    it "requires a Paddle price id" do
      expect(build_product(paddle_price_id: nil)).not_to be_valid
    end

    it "requires a name in the default locale" do
      product = Product.new(paddle_price_id: "pri_456", kind: :bedtime_story)

      expect(product).not_to be_valid
      expect(product.errors[:name]).to be_present
    end
  end

  describe "scopes" do
    it "lists published products in position order" do
      second = create_product(name: "Druga", position: 2)
      first = create_product(name: "Pierwsza", position: 1)
      create_product(name: "Ukryta", published: false)

      expect(Product.published.ordered).to eq([ first, second ])
    end
  end
end
