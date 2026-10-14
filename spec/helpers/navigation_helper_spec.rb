require 'rails_helper'

RSpec.describe NavigationHelper, type: :helper do
  describe "#primary_nav_items" do
    it "lists the public pages in the order they appear in the bar" do
      expect(helper.primary_nav_items.map { |item| item[:label] })
        .to eq([ "Audioprocesy", "Bajki audio", "Współpraca 1:1" ])
    end

    it "points each entry at its page" do
      hrefs = helper.primary_nav_items.to_h { |item| [ item[:label], item[:href] ] }

      expect(hrefs["Audioprocesy"]).to eq(audio_process_path)
      expect(hrefs["Bajki audio"]).to eq(stories_path)
      expect(hrefs["Współpraca 1:1"]).to eq(packages_path)
    end

    # The blog remains parked independently of the live catalogue links.
    it "leaves out the parked blog" do
      expect(helper.primary_nav_items.map { |item| item[:label] }).not_to include("Blog")
    end
  end
end
