require "rails_helper"

RSpec.describe "Front page approach disclosures", type: :system do
  after do
    page.driver.browser.execute_cdp("Emulation.setScriptExecutionDisabled", value: false)
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  [ nil, :en ].each do |locale|
    it "keeps both full explanations available without JavaScript for #{locale || :pl}" do
      ContentBlock.sync!
      ContentBlock.find_by!(key: "home.methodology.summary").update!(
        value_pl: "Małe kroki dla Waszej rodziny.", value_en: "Small steps for your family.")
      ContentBlock.find_by!(key: "home.methodology.body").update!(
        body_pl: "<p>Pełna opowieść o mojej pracy.</p>", body_en: "<p>The full story of how I work.</p>")
      ContentBlock.find_by!(key: "home.disagree.body").update!(
        body_pl: "<p>Pełna opowieść o moich granicach.</p>", body_en: "<p>The full story of my boundaries.</p>")
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
        width: 390, height: 844, deviceScaleFactor: 1, mobile: false)
      page.driver.browser.execute_cdp("Emulation.setScriptExecutionDisabled", value: true)
      visit root_path(locale: locale)

      first = 'article[aria-labelledby="methodology-title"]'
      second = 'article[aria-labelledby="disagree-title"]'
      summary = locale ? "Small steps for your family." : "Małe kroki dla Waszej rodziny."
      more = locale ? "Read more" : "Czytaj więcej"
      less = locale ? "Show less" : "Zwiń tekst"
      expect(page).to have_text(summary)
      expect(page).to have_css("#{first} summary", text: more)
      expect(page).not_to have_css("#{first} .trix-copy", visible: true)
      expect(page).not_to have_css("#{second} .trix-copy", visible: true)

      find("#{first} summary").send_keys(:enter)
      expect(page).to have_css("#{first} details[open]")
      expect(page).to have_css("#{first} summary", text: less)
      expect(page).to have_css("#{first} .trix-copy", visible: true)
      expect(page).not_to have_css("#{second} details[open]")
      find("#{first} summary").send_keys(:space)
      expect(page).not_to have_css("#{first} details[open]")
      expect(page).to have_css("#{first} summary:focus", text: more)

      find("#{second} summary").click
      expect(page).to have_css("#{second} .trix-copy", visible: true)
      expect(page).not_to have_css("#{first} details[open]")
      expect(page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth")).to be(true)
    end
  end
end
