require "rails_helper"

RSpec.describe "Package details", type: :system do
  include Warden::Test::Helpers

  before do
    allow(GoogleCalendarService).to receive(:call).and_return(instance_double(GoogleCalendarService, busy: []))
    allow(PaddlePriceCatalogService).to receive(:call).and_return([ paddle_price ])
  end

  after { Warden.test_reset! }

  it "opens the right modal, traps focus and restores it after closing" do
    first = create_package(name: "Pierwszy")
    second = create_package(name: "Drugi")
    second.assign_translation(:organization, :pl, "Dzienniczek i godziny kontaktu")
    second.save!
    selector = "#package-details-#{second.id}"
    trigger = 'button[aria-label="Poznaj szczegóły - Drugi"]'

    visit packages_path
    expect(page).not_to have_css("dialog[open]")
    find(trigger).send_keys(:enter)
    expect(page).to have_css("#{selector}[open] [data-dialog-heading]:focus")
    expect(page).not_to have_css("#package-details-#{first.id}[open]")
    expect(URI.parse(page.current_url).fragment).to eq(selector.delete_prefix("#"))
    expect(page).to have_css("html.package-details-modal-open")
    expect(page).to have_text("Dzienniczek i godziny kontaktu")
    5.times do
      page.driver.browser.action.send_keys(:tab).perform
      expect(page.evaluate_script("document.activeElement.closest('dialog')?.id")).to eq(selector.delete_prefix("#"))
    end
    page.driver.browser.action.send_keys(:escape).perform
    expect(page).not_to have_css("dialog[open]")
    expect(page).not_to have_css("html.package-details-modal-open")
    expect(page).to have_css("#{trigger}:focus")
    expect(URI.parse(page.current_url).fragment).to be_nil

    find(trigger).click
    within("#{selector}[open]") { click_button "Zamknij" }
    expect(page).not_to have_css("dialog[open]")
    expect(page).to have_css("#{trigger}:focus")

    find(trigger).click
    page.driver.browser.action.move_to_location(2, 2).click.perform
    expect(page).not_to have_css("dialog[open]")
    expect(page).to have_css("#{trigger}:focus")

    visit root_path
    visit "#{packages_path}#{selector}"
    expect(page).to have_css("#{selector}[open] [data-dialog-heading]:focus")
    page.driver.browser.action.send_keys(:escape).perform
    expect(page).to have_css("#{trigger}:focus")
  end

  it "closes the modal when booking and restores the calendar on the page" do
    package = create_package(name: "Pakiet")
    visit packages_path
    find("button[aria-controls='package-details-#{package.id}']").click
    within("dialog[open]") { click_link "Zobacz terminy" }
    expect(page).not_to have_css("dialog[open]")
    expect(page).not_to have_css("html.package-details-modal-open")
    expect(page).to have_current_path(%r{/packages#calendar\z}, url: true)
    expect(page).to have_css("#calendar:focus")
  end

  it "warns as the admin writes, without truncating or blocking the save" do
    admin = User.create!(email: "editor@example.com", password: "password123", admin: true)
    login_as admin, scope: :user
    package = create_package
    visit edit_admin_package_path(package)
    fill_in "record-for_whom-pl", with: "a" * 221
    expect(page).to have_css("#record-for_whom-pl-warning", text: "Opis ma 221 znaków")
    fill_in "record-highlights-pl", with: (1..6).map { |n| "Wyróżnik #{n}" }.join("\n")
    expect(page).to have_css("#record-highlights-pl-warning", text: "Wpisano 6 wyróżników")
    fill_in "record-highlights-en", with: "x" * 141
    expect(page).to have_css("#record-highlights-en-warning", text: "Skróć wyróżniki do 140 znaków")
    fill_in "record-for_whom-pl", with: "Krótki opis"
    expect(page).not_to have_css("#record-for_whom-pl-warning", visible: true)
    click_button "Zapisz pakiet"
    expect(page).to have_current_path(admin_packages_path)
    expect(package.reload.highlights.size).to eq(6)
    expect(package.raw_translation(:highlights, :en)).to eq([ "x" * 141 ])
  end
end
