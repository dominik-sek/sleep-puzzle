require "rails_helper"

RSpec.describe "Product slug regeneration", type: :model do
  def regenerate(product, name)
    product.assign_translation(:name, :pl, name)
    product.regenerate_slug = true
    product.slug_preview = product.suggested_slug
    product.save!
  end

  it "remembers every address and can return to its own earlier slug" do
    product = create_product(name: "Pierwsza nazwa")
    regenerate(product, "Druga nazwa")
    regenerate(product, "Trzecia nazwa")
    expect(product.slug_histories.pluck(:slug)).to match_array(%w[pierwsza-nazwa druga-nazwa trzecia-nazwa])

    regenerate(product, "Pierwsza nazwa")
    expect(product.reload.slug).to eq("pierwsza-nazwa")
    expect(product.slug_histories.count).to eq(3)
  end

  it "reserves old names across product kinds" do
    original = create_product(name: "Sowa")
    regenerate(original, "Nowa sowa")
    replacement = create_product(name: "Sowa", kind: :audio_process)
    expect(replacement.slug).to eq("sowa-2")

    regenerate(replacement, "Nowa sowa")
    expect(replacement.slug).to eq("nowa-sowa-2")
  end

  it "rejects a stale preview instead of silently saving a different address" do
    product = create_product(name: "Sowa")
    product.assign_translation(:name, :pl, "Las")
    product.regenerate_slug = true
    product.slug_preview = product.suggested_slug
    create_product(name: "Las")

    expect(product.save).to be(false)
    expect(product.errors[:base].join).to include("Wygeneruj podgląd ponownie")
    expect(product.reload.slug).to eq("sowa")
    expect(product.slug_histories.pluck(:slug)).to eq([ "sowa" ])
  end

  it "does not remember a new slug when other form validation fails" do
    product = create_product(name: "Sowa")
    product.assign_translation(:name, :pl, "Las")
    product.regenerate_slug = true
    product.slug_preview = product.suggested_slug
    product.position = -1
    expect(product.save).to be(false)
    expect(product.reload.slug).to eq("sowa")
    expect(product.slug_histories.pluck(:slug)).to eq([ "sowa" ])
  end

  it "requires explicit regeneration and clears the request after a successful save" do
    product = create_product(name: "Sowa")
    product.slug = "manual-slug"
    expect(product.save).to be(false)
    product.reload
    regenerate(product, "Las")
    expect(product).not_to be_regenerate_slug
    product.assign_translation(:name, :pl, "Jeszcze inna nazwa")
    product.save!
    expect(product.reload.slug).to eq("las")
  end

  it "does not add a duplicate history entry when the name yields the current slug" do
    product = create_product(name: "Sowa")
    expect { regenerate(product, "SOWA!") }.not_to change(ProductSlugHistory, :count)
    expect(product.slug).to eq("sowa")
  end
end
