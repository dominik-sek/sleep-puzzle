require 'rails_helper'

RSpec.describe ContactMessage do
  def message(**overrides)
    described_class.new(
      { name: "Jan Kowalski", email: "jan@example.com", body: "Pytanie o pakiet." }.merge(overrides)
    )
  end

  it "is valid with a name, an address and a message" do
    expect(message).to be_valid
  end

  # a pasted address often arrives with a space on one end, and the format check
  # would otherwise reject something the sender typed correctly
  it "trims the name and the address" do
    trimmed = message(name: "  Jan Kowalski  ", email: " jan@example.com\n")

    expect(trimmed).to be_valid
    expect(trimmed.name).to eq("Jan Kowalski")
    expect(trimmed.email).to eq("jan@example.com")
  end

  it "survives being handed nothing at all" do
    expect(described_class.new(name: nil, email: nil, body: nil)).not_to be_valid
  end

  it "rejects a message longer than the limit" do
    expect(message(body: "a" * described_class::BODY_LIMIT)).to be_valid
    expect(message(body: "a" * (described_class::BODY_LIMIT + 1))).not_to be_valid
  end

  it "rejects an overlong name" do
    expect(message(name: "a" * 101)).not_to be_valid
  end

  # blank and malformed are different problems, and saying both at once for an
  # empty field reads as noise
  it "says only that the address is missing when it is blank" do
    blank = message(email: "")
    blank.validate

    expect(blank.errors[:email]).to eq([ "Podaj adres e-mail" ])
  end

  it "rejects an address that is not one" do
    malformed = message(email: "jan(at)example")
    malformed.validate

    expect(malformed.errors[:email]).to eq([ "Podaj prawidłowy adres e-mail" ])
  end
end
