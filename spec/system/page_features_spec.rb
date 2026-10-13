require "rails_helper"

RSpec.describe "Deferred page features", type: :system do
  include Warden::Test::Helpers

  before do
    ContentBlock.sync!
    create_product(kind: :audio_process)
    allow(PaddlePriceCatalogService).to receive(:call).and_return([ paddle_price(id: "pri_456") ])
    allow(GoogleCalendarService).to receive(:call).and_return(instance_double(GoogleCalendarService, busy: []))
  end

  after { Warden.test_reset! }

  it "leaves the editor and calendar unloaded on the audio landing page" do
    visit audio_process_path
    expect(page).to have_css("[data-controller='navbar']")
    expect(page.evaluate_script("Boolean(customElements.get('trix-editor'))")).to be(false)
    expect(page.evaluate_script("Boolean(customElements.get('calendar-date'))")).to be(false)
    resources = page.evaluate_script("performance.getEntriesByType('resource').map(entry => entry.name)")
    expect(resources.join(" ")).not_to match(/rich_text_editor|cally_controller/)
    find('button[aria-label^="Dodaj do koszyka"]').click
    expect(page).to have_css('button[aria-label^="Usuń z koszyka"]')
  end

  it "initializes the calendar on a Turbo visit and accepts the first date selection" do
    visit audio_process_path
    page.execute_script("Turbo.visit(arguments[0])", packages_path)
    expect(page).to have_css("calendar-date")
    expect(page.evaluate_script("Boolean(document.querySelector('calendar-month').shadowRoot)")).to be(true)
    panel = first('[data-cally-target="hoursPanel"]:has(button:not(:disabled))', visible: :all)
    date = panel[:"data-date"]
    page.execute_script(<<~JS, date)
      const calendar = document.querySelector("calendar-date")
      calendar.value = arguments[0]
      calendar.dispatchEvent(new Event("change", { bubbles: true }))
    JS
    expect(page).to have_css("[data-cally-target='hoursPanel'][data-date='#{date}']:not([hidden])")
    expect(page.evaluate_script("Boolean(customElements.get('trix-editor'))")).to be(false)
  end

  it "loads a rich editor introduced by a Turbo visit and saves typed content" do
    admin = User.create!(email: "page-features@example.com", password: "password123", admin: true)
    login_as admin, scope: :user
    visit admin_content_blocks_path
    expect(page.evaluate_script("Boolean(customElements.get('trix-editor'))")).to be(false)

    within('nav[aria-label="Sekcje strony"]') { click_link "O mnie" }
    editor = find("trix-editor", match: :first)
    expect(editor["contenteditable"]).not_to be_nil
    editor.click
    editor.send_keys("Treść po odroczonym ładowaniu")
    click_button "Zapisz sekcję"
    expect(page).to have_css("trix-editor", text: "Treść po odroczonym ładowaniu")
    expect(ContentBlock.find_by!(key: "home.about.lead").body_pl.to_plain_text).to include("Treść po odroczonym ładowaniu")
  end

  it "upgrades a rich editor inserted into an existing page by a Turbo Stream" do
    visit audio_process_path
    page.execute_script(<<~JS)
      Turbo.renderStreamMessage(`<turbo-stream action="append" target="main-content"><template>
        <input type="hidden" id="stream-editor-value">
        <trix-editor input="stream-editor-value" id="stream-editor"></trix-editor>
      </template></turbo-stream>`)
    JS
    editor = find("#stream-editor[contenteditable]")
    editor.click
    editor.send_keys("Treść dodana przez stream")
    expect(find("#stream-editor-value", visible: :all).value).to include("Treść dodana przez stream")
  end
end
