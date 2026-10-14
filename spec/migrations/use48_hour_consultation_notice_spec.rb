require "rails_helper"
require Rails.root.join("db/migrate/20261014140000_use48_hour_consultation_notice")

RSpec.describe Use48HourConsultationNotice do
  let(:plan) { JSON.parse(Rails.root.join("config/refund_policy_48_hours_20261014.json").read) }

  it "updates both languages of the stored policy and terms, preserving historical purchases" do
    items = plan.group_by { |change| change.fetch("collection") }.map do |collection, changes|
      ContentItem.create!(collection_key: collection, position: 1,
        values: { "body" => changes.to_h { |change| [ change.fetch("locale"), change.fetch("expected") ] } })
    end
    user = User.create!(email: "previous-notice@example.com", password: "password123")
    snapshot = RefundPolicySnapshot.build(:booking)
    snapshot["booking_notice_periods"]["canceled"] = { "amount" => 14, "unit" => "days" }
    snapshot["clauses"] = plan.select { |change| change["collection"] == "refunds.clauses" && change["locale"] == "pl" }
      .map { |change| { "body" => change.fetch("expected") } }
    booking = user.bookings.create!(package: create_package, name: "Marta", email: user.email,
      starts_at: 1.month.from_now, legal_snapshot: snapshot)

    2.times { described_class.new.up }

    items.each do |item|
      plan.select { |change| change["collection"] == item.collection_key }.each do |change|
        expect(item.reload.values.dig(change.fetch("field"), change.fetch("locale"))).to eq(change.fetch("replacement"))
      end
    end
    expect(booking.reload.legal_snapshot).to eq(snapshot)
  end

  it "preserves custom CMS copy independently in each language" do
    changes = plan.select { |change| change["collection"] == "refunds.clauses" }.index_by { |change| change.fetch("locale") }
    item = ContentItem.create!(collection_key: "refunds.clauses", position: 1,
      values: { "body" => { "pl" => "Własne zasady Karoli", "en" => changes.fetch("en").fetch("expected") } })

    described_class.new.up

    expect(item.reload.values.dig("body", "pl")).to eq("Własne zasady Karoli")
    expect(item.values.dig("body", "en")).to eq(changes.fetch("en").fetch("replacement"))
    item.update!(values: { "body" => { "pl" => "Własne zasady Karoli", "en" => "New custom terms" } })
    described_class.new.down
    expect(item.reload.values.dig("body", "en")).to eq("New custom terms")
  end

  it "restores unchanged copy on rollback" do
    change = plan.first
    item = ContentItem.create!(collection_key: change.fetch("collection"), position: 1,
      values: { change.fetch("field") => { change.fetch("locale") => change.fetch("replacement") } })

    described_class.new.down

    expect(item.reload.values.dig(change.fetch("field"), change.fetch("locale"))).to eq(change.fetch("expected"))
  end
end
