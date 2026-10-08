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
  it "warns only when a summary exceeds the recommended length" do
    expect(helper.package_copy_warning("summary", "a" * 220)).to eq("")
    expect(helper.package_copy_warning("summary", "a" * 221)).to include("221 znaków", "szczegółach")
  end

  it "counts nonempty highlights and warns about long entries" do
    expect(helper.package_copy_warning("highlights", "Plan\n\nWsparcie")).to eq("")
    expect(helper.package_copy_warning("highlights", Array.new(6, "Plan").join("\n"))).to include("6 wyróżników")
    expect(helper.package_copy_warning("highlights", "x" * 141)).to include("140 znaków")
  end
end
