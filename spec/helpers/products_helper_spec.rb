require "rails_helper"

RSpec.describe ProductsHelper, type: :helper do
  def includes_parts(html)
    product = build_product(kind: :audio_process)
    product.includes_pl = html
    helper.audio_includes_parts(product)
  end

  it "keeps two whole opening paragraphs visible and preserves the remaining rich text" do
    intro, details = includes_parts("<!-- rendered partial --><p>Krótki opis.</p><p>Słuchasz we własnym tempie.</p><p>Dalszy opis.</p><ul><li><strong>Rytm dnia</strong> i rutyna.</li></ul><!-- end partial -->")

    expect(Nokogiri::HTML.fragment(intro).css("p").map(&:text)).to eq([ "Krótki opis.", "Słuchasz we własnym tempie." ])
    remainder = Nokogiri::HTML.fragment(details)
    expect(remainder.at_css("p").text).to eq("Dalszy opis.")
    expect(remainder.at_css("li strong").text).to eq("Rytm dnia")
  end

  it "leaves short copy visible without a disclosure" do
    intro, details = includes_parts("<!-- rendered partial --><p>Cała zawartość.</p><!-- end partial -->")

    expect(intro).to include("Cała zawartość.")
    expect(details).to be_nil
  end

  it "preserves a long single paragraph without truncation" do
    text = "Warunek współpracy. " * 30
    intro, details = includes_parts("<p>#{text}</p>")

    expect(intro).to be_nil
    expect(Nokogiri::HTML.fragment(details).at_css("p").text.strip).to eq(text.strip)
  end

  it "keeps list-first content and nested topics together" do
    intro, details = includes_parts("<ul><li>Pierwszy temat<ul><li>Szczegół</li></ul></li><li>Drugi temat</li></ul>")

    expect(intro).to be_nil
    remainder = Nokogiri::HTML.fragment(details)
    expect(remainder.css("li").size).to eq(3)
    expect(remainder.at_css("li ul li").text).to eq("Szczegół")
  end
end
