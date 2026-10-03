require "rails_helper"

RSpec.describe "Admin content editor", type: :system do
  include Warden::Test::Helpers

  let(:admin) { User.create!(email: "content-owner@example.com", password: "password123", admin: true) }

  before do
    ContentBlock.sync!
    login_as admin, scope: :user
  end

  after { Warden.test_reset! }

  it "finds a section, switches languages without losing a draft, and opens its preview" do
    title = ContentBlock.find_by!(key: "about.certifications.title")
    title.update!(value_pl: "Polski tytuł")
    page.driver.browser.manage.window.resize_to(1280, 900)
    visit admin_content_blocks_path

    fill_in "Znajdź treść", with: "doswiadczenie"
    within('nav[aria-label="Wyniki wyszukiwania"]') { click_link "Certyfikaty" }
    expect(page).to have_css('#section-about-certifications')

    find('[data-content-blocks-target="languageTab"][data-lang="en"]').click
    fill_in "Nagłówek — English", with: "Draft title"
    find('[data-content-blocks-target="languageTab"][data-lang="pl"]').click
    find('[data-content-blocks-target="languageTab"][data-lang="en"]').click
    expect(find_field("Nagłówek — English").value).to eq("Draft title")

    click_button "Podgląd"
    expect(page).to have_css('iframe[title="Podgląd strony"][src="/en/about"]', visible: :all)
    expect(page).to have_css('.cms-editor', visible: true)
    expect(page).to have_css('#content-preview', visible: true)
    within_frame(find('iframe[title="Podgląd strony"]')) do
      expect(page).to have_content("Draft title")
    end

    click_button "Zapisz sekcję"
    expect(page).to have_css('#section-about-certifications')
    query = URI.decode_www_form(URI(page.current_url).query).to_h
    expect(query).to include("open" => "about.certifications", "lang" => "en")
    expect(find_field("Nagłówek — English").value).to eq("Draft title")
    expect(title.reload.value_en).to eq("Draft title")
    expect(title.value_pl).to eq("Polski tytuł")
  end

  it "warns before leaving an edited section" do
    visit admin_content_blocks_path
    fill_in "Nagłówek — Polski", with: "Niezapisany szkic"

    dismiss_confirm("Masz niezapisane zmiany") { within('nav[aria-label="Sekcje strony"]') { click_link "O mnie" } }
    expect(page).to have_css('#section-home-hero')
    expect(find_field("Nagłówek — Polski").value).to eq("Niezapisany szkic")

    accept_confirm("Masz niezapisane zmiany") { within('nav[aria-label="Sekcje strony"]') { click_link "O mnie" } }
    expect(page).to have_css('#section-home-about')
  end

  it "switches between editing and preview on a narrow screen" do
    page.driver.browser.manage.window.resize_to(900, 800)
    visit admin_content_blocks_path

    click_button "Podgląd"
    expect(page).to have_css('#content-preview', visible: true)
    expect(page).to have_no_css('.cms-editor', visible: true)

    click_button "Zamknij podgląd", match: :first
    expect(page).to have_css('.cms-editor', visible: true)
  end

  it "keeps the selected section and language while adding and removing a list item" do
    visit admin_content_blocks_path(open: "home.faq", lang: "en")

    click_link "Dodaj: pytanie"
    expect(page).to have_css('#section-home-faq')
    added = ContentItem.for_collection("home.faq").order(:id).last
    expect(page).to have_css("#item-#{added.id}-position")
    expect(page).to have_css('[data-content-blocks-target="languageTab"][data-lang="en"][aria-pressed="true"]')

    accept_confirm("Usunąć ten element?") { find("a[href*='/admin/content_items/#{added.id}']").click }
    expect(page).to have_no_css("#item-#{added.id}-position")
    expect(ContentItem.exists?(added.id)).to be(false)
  end
end
