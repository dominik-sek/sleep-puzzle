require "rails_helper"
require Rails.root.join("db/migrate/20261014100000_update_refund_policy_scope")

RSpec.describe UpdateRefundPolicyScope do
  let(:plan) { JSON.parse(Rails.root.join("config/refund_policy_copy_20261014.json").read) }

  it "updates stored defaults in both languages without changing edited copy or purchase snapshots" do
    entry = plan.fetch("items").find { |change| change["collection"] == "terms.clauses" && change["locale"] == "pl" }
    translation = plan.fetch("items").find { |change| change["collection"] == entry["collection"] && change["expected"] != entry["expected"] && change["locale"] == "en" }
    item = ContentItem.create!(collection_key: entry["collection"], position: 1,
      values: { "body" => { "pl" => entry["expected"], "en" => translation["expected"] } })
    custom = ContentItem.create!(collection_key: entry["collection"], position: 2,
      values: { "body" => { "pl" => "Indywidualny zapis właścicielki" } })
    old_title = plan.fetch("blocks").find { |change| change["locale"] == "pl" }
    block = ContentBlock.create!(key: old_title["key"], value_pl: old_title["expected"], value_en: "Custom title")
    user = User.create!(email: "old-policy@example.com", password: "password123")
    order = user.orders.create!(status: :paid, legal_snapshot: { "title" => old_title["expected"], "clauses" => [ { "body" => entry["expected"] } ] },
      order_items: [ OrderItem.new(product: create_product) ])
    saved = order.legal_snapshot.deep_dup

    2.times { described_class.new.up }

    expect(item.reload.values.dig("body", "pl")).to eq(entry["replacement"])
    expect(item.values.dig("body", "en")).to eq(translation["replacement"])
    expect(custom.reload.values.dig("body", "pl")).to eq("Indywidualny zapis właścicielki")
    expect(block.reload.value_pl).to eq(old_title["replacement"])
    expect(block.value_en).to eq("Custom title")
    expect(order.reload.legal_snapshot).to eq(saved)
  end

  it "can restore an unchanged replacement without overwriting subsequent edits" do
    change = plan.fetch("items").first
    item = ContentItem.create!(collection_key: change["collection"], position: 1,
      values: { change["field"] => { change["locale"] => change["replacement"] } })
    described_class.new.down
    expect(item.reload.values.dig(change["field"], change["locale"])).to eq(change["expected"])
  end

  it "updates the stored cancellation and rescheduling clauses to their distinct thresholds" do
    cancellation = plan.fetch("items").find { |entry| entry["collection"] == "refunds.clauses" && entry["locale"] == "pl" && entry["expected"].start_with?("Pojedynczą konsultację") }
    rescheduling = plan.fetch("items").find { |entry| entry["collection"] == "refunds.clauses" && entry["locale"] == "pl" && entry["expected"].start_with?("Przełożenie") }
    cancel_item = ContentItem.create!(collection_key: "refunds.clauses", position: 1,
      values: { "body" => { "pl" => cancellation["expected"] } })
    move_item = ContentItem.create!(collection_key: "refunds.clauses", position: 2,
      values: { "body" => { "pl" => rescheduling["expected"] } })
    described_class.new.up
    expect(cancel_item.reload.values.dig("body", "pl")).to include("co najmniej 14 dni przed")
    expect(move_item.reload.values.dig("body", "pl")).to include("co najmniej 48 godzin", "wcześniejszego uzgodnienia")
  end
end
