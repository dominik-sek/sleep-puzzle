require 'rails_helper'

# Specs in this file have access to a helper object that includes
# the PackagesHelper. For example:
#
# describe PackagesHelper do
#   describe "string concat" do
#     it "concats two strings with spaces" do
#       expect(helper.concat_strings("this","that")).to eq("this that")
#     end
#   end
# end
RSpec.describe PackagesHelper, type: :helper do
  it "reuses only the opening collaboration paragraph on the shop" do
    allow(helper).to receive(:content_block).with("packages.collaboration.body").and_return(
      '<div class="trix-content"><p>Opening <strong>words</strong>.</p><p>Later explanation.</p><figure><img src="/comparison.png" alt="Comparison"></figure></div>'
    )
    expect(helper.shop_collaboration_intro).to eq("Opening words.")
  end

  it "warns only when a summary exceeds the recommended length" do
    expect(helper.package_copy_warning("summary", "a" * 220)).to eq("")
    expect(helper.package_copy_warning("summary", "a" * 221)).to include("221 znaków", "szczegółach")
  end

  it "counts nonempty highlights and warns about long entries" do
    expect(helper.package_copy_warning("highlights", "Plan\n\nWsparcie")).to eq("")
    expect(helper.package_copy_warning("highlights", Array.new(6, "Plan").join("\n"))).to include("6 wyróżników")
    expect(helper.package_copy_warning("highlights", "x" * 141)).to include("140 znaków")
  end

  it "keeps imported remote artwork available when its signed attachment cannot resolve" do
    source = "https://example.com/comparison.png"
    allow(helper).to receive(:content_block).with("packages.collaboration.body").and_return(
      %(<div>Introduction</div><action-text-attachment sgid="stale" content-type="image/png" url="#{source}" width="600" height="800"></action-text-attachment>)
    )

    body, comparison = helper.package_collaboration_parts

    expect(body).to include("Introduction")
    expect(body).not_to include("action-text-attachment")
    expect(comparison).to eq(src: source, thumbnail_src: source, width: 600, height: 800)
  end

  it "reuses an embedded preview when imported artwork already provides one" do
    allow(helper).to receive(:content_block).with("packages.collaboration.body").and_return(
      '<action-text-attachment content-type="image/png" url="/original.png"><img src="/preview.png"></action-text-attachment>'
    )

    _, comparison = helper.package_collaboration_parts

    expect(comparison).to include(src: "/original.png", thumbnail_src: "/preview.png")
  end
end
