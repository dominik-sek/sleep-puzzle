require 'rails_helper'

# == Schema Information
#
# Table name: products
#
#  id              :bigint           not null, primary key
#  category        :integer
#  cdn_path        :string
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

  # The path is signed exactly as it appears in the URL, so anything needing
  # percent-encoding would be signed in one form and requested in another, and
  # every play would come back a 403 from Bunny.
  describe "the audio file's path" do
    it "accepts a plain path" do
      expect(build_product(cdn_path: "/bajki/o-sowie.mp3")).to be_valid
    end

    # The file is what a product sells, so it is only optional while the product
    # is still hidden — a draft the owner is filling in.
    it "is optional while the product is unpublished" do
      expect(build_product(cdn_path: nil, published: false)).to be_valid
      expect(build_product(cdn_path: "", published: false)).to be_valid
    end

    it "is required to publish" do
      expect(build_product(cdn_path: nil, published: true)).not_to be_valid
      expect(build_product(cdn_path: "", published: true)).not_to be_valid
    end

    # Bunny's file browser shows paths both ways, and the owner pastes what they see
    it "adds the leading slash the owner left off" do
      product = create_product(cdn_path: "bajki/o-sowie.mp3")

      expect(product.cdn_path).to eq("/bajki/o-sowie.mp3")
    end

    it "trims surrounding whitespace from a paste" do
      product = create_product(cdn_path: "  /bajki/o-sowie.mp3  ")

      expect(product.cdn_path).to eq("/bajki/o-sowie.mp3")
    end

    it "rejects a path that would not survive a URL intact" do
      [ "/bajki/o sowie.mp3", "/bajki/ó-sowie.mp3", "/bajki/o-sowie.mp3?x=1", "https://cdn.example/x.mp3" ].each do |path|
        product = build_product(cdn_path: path)

        expect(product).not_to be_valid, "expected #{path.inspect} to be rejected"
        expect(product.errors[:cdn_path]).to be_present
      end
    end
  end

  describe "#streamable?" do
    it "is true for an uploaded file with the CDN configured" do
      with_bunny_cdn

      expect(build_product(cdn_path: "/bajki/o-sowie.mp3")).to be_streamable
    end

    it "is false before the file is uploaded" do
      with_bunny_cdn

      expect(build_product(cdn_path: nil)).not_to be_streamable
    end

    # development and the test suite, where the library renders exactly as it did
    # before the CDN existed
    it "is false with no CDN credentials" do
      expect(build_product(cdn_path: "/bajki/o-sowie.mp3")).not_to be_streamable
    end
  end

  describe "scopes" do
    it "lists published products in position order" do
      second = create_product(name: "Druga", position: 2)
      first = create_product(name: "Pierwsza", position: 1)
      create_product(name: "Ukryta", published: false)

      expect(Product.published.ordered).to eq([ first, second ])
    end

    # The validation only covers rows saved from now on. This is the layer that
    # keeps a product published before the rule existed — or flipped straight
    # through SQL — out of the shop, the home teaser and the cart.
    it "leaves out a published product whose file is missing" do
      missing = create_product(name: "Bez pliku")
      missing.update_column(:cdn_path, nil)

      blank = create_product(name: "Pusta ścieżka", paddle_price_id: "pri_999")
      blank.update_column(:cdn_path, "")

      expect(Product.published).not_to include(missing, blank)
    end
  end
end
