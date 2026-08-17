require 'rails_helper'

# The footer renders on every page through the layout, so it is exercised here
# through the home page rather than in isolation.
RSpec.describe "Footer", type: :request do
  it "renders its CMS copy from the declared defaults on an empty database" do
    expect(ContentBlock.count).to eq(0)

    get root_path

    expect(response.body).to include("Odkrywaj", "Konto", "Bądźmy w kontakcie")
    expect(response.body).to include("Pomagam rodzinom spokojnie poukładać sen")
    expect(response.body).not_to include("brak treści")
  end

  it "uses what the owner typed instead of the default" do
    ContentBlock.sync!
    ContentBlock.find_by!(key: "footer.columns.explore").update!(value_pl: "Zobacz też")

    get root_path

    expect(response.body).to include("Zobacz też")
    expect(response.body).not_to include("Odkrywaj")
  end

  it "renders the English copy under the English locale" do
    I18n.with_locale(:en) { get root_path }

    expect(response.body).to include("Explore", "Account", "Stay in touch")
    expect(response.body).to include("Helping families calmly piece sleep back together")
  end

  it "links the pages that exist and leaves the unbuilt ones as plain text" do
    get root_path

    expect(response.body).to include(%(href="#{packages_path}"), %(href="#{about_path}"))
    expect(response.body).to include(%(href="#{bookings_path}"), %(href="#{contact_path}"))
    expect(response.body).to include(%(href="https://www.instagram.com/sleep.puzzle"))
    # no page to point at yet, so these must not become dead links
    expect(response.body).not_to include(%(<a href="#">Sklep</a>))
  end

  it "takes the copyright year from the clock rather than a typed-in one" do
    get root_path

    expect(response.body).to include("© #{Date.current.year} Sleep Puzzle")
  end
end
