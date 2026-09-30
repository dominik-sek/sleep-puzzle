require 'rails_helper'

RSpec.describe "Shared testimonials", type: :request do
  it "uses the same admin-managed entry on the home page and both landings" do
    item = ContentItem.create!(collection_key: "testimonials.entries", position: 1)
    item.assign_value("quote", :pl, "Wreszcie mamy spokojne wieczory")
    item.assign_value("author", :pl, "Rodzic")
    item.assign_value("effect", :pl, "Łatwiejsze zasypianie")
    item.save!
    allow(GoogleCalendarService).to receive(:call).and_return(instance_double(GoogleCalendarService, busy: []))

    [ root_path, audio_process_path, packages_path ].each do |path|
      get path

      expect(response.body).to include("Wreszcie mamy spokojne wieczory", "Łatwiejsze zasypianie")
    end
  end
end
