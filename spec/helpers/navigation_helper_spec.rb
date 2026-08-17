require 'rails_helper'

RSpec.describe NavigationHelper, type: :helper do
  describe "#primary_nav_items" do
    it "lists the public pages in the order they appear in the bar" do
      expect(helper.primary_nav_items.map { |item| item[:label] })
        .to eq([ "Pakiety", "O mnie", "Sklep", "Kontakt" ])
    end

    it "points each entry at its page" do
      hrefs = helper.primary_nav_items.to_h { |item| [ item[:label], item[:href] ] }

      expect(hrefs["Pakiety"]).to eq(packages_path)
      expect(hrefs["O mnie"]).to eq(about_path)
      expect(hrefs["Kontakt"]).to eq(contact_path)
    end

    # the blog is parked and the shop is unbuilt; neither should quietly acquire a
    # route here before the page exists
    it "leaves out the parked blog" do
      expect(helper.primary_nav_items.map { |item| item[:label] }).not_to include("Blog")
    end
  end
end
