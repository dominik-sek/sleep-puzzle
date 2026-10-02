require "rails_helper"

RSpec.describe "Package card layout", type: :system do
  it "keeps three cards and their actions aligned on a laptop" do
    allow(GoogleCalendarService).to receive(:call).and_return(instance_double(GoogleCalendarService, busy: []))
    allow(PaddlePriceCatalogService).to receive(:call).and_return([ paddle_price ])

    3.times do |index|
      package = build_package(name: "Pakiet #{index + 1}", position: index)
      package.assign_translation_list(:core, :pl, Array.new(index + 1, "Konsultacja i wsparcie rodziców"))
      package.save!
    end

    page.driver.browser.manage.window.resize_to(900, 900)
    visit packages_path
    expect(page).to have_css('[id^="package_"]', count: 3)

    cards = page.evaluate_script(<<~JS)
      [...document.querySelectorAll('[id^="package_"]')].map(card => {
        const box = card.getBoundingClientRect();
        const button = card.querySelector('a[aria-label^="Zobacz terminy"]');
        return { top: box.top, width: box.width, buttonTop: button.getBoundingClientRect().top };
      })
    JS

    expect(cards.map { |card| card["top"].round }.uniq.size).to eq(1)
    expect(cards.map { |card| card["buttonTop"].round }.uniq.size).to eq(1)
    expect(cards.map { |card| card["width"] }.max).to be <= 376
  end
end
