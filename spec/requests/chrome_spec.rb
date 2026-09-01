require 'rails_helper'

# The navbar and footer were hardcoded Polish, so English pages rendered Polish
# chrome around translated content - the switcher looked half-finished.
RSpec.describe "Navbar and footer copy", type: :request do
  let(:user) { User.create!(email: "customer@example.com", password: "password123") }

  describe "in Polish" do
    it "reads Polish" do
      get root_path

      expect(response.body).to include("Pakiety")
      expect(response.body).to include("O mnie")
      expect(response.body).to include("Umów konsultację")
      expect(response.body).to include("Zaloguj się")
      expect(response.body).to include("Wszelkie prawa zastrzeżone")
    end
  end

  describe "in English" do
    it "translates the nav links" do
      get root_path(locale: :en)

      expect(response.body).to include("Packages")
      expect(response.body).to include("About me")
      expect(response.body).to include("Shop")
      expect(response.body).to include("Contact")
      # not asserted by absence of "Pakiety": CMS copy with no English version
      # deliberately falls back to Polish, and the home page's section headings
      # have not been translated by the owner yet
      expect(response.body).not_to include(">O mnie<")
    end

    it "translates the calls to action and the sign-in button" do
      get root_path(locale: :en)

      expect(response.body).to include("Book a consultation")
      expect(response.body).to include("Log in")
      expect(response.body).not_to include("Umów konsultację")
      expect(response.body).not_to include("Zaloguj się")
    end

    it "translates the footer" do
      get root_path(locale: :en)

      expect(response.body).to include("Terms of cooperation")
      expect(response.body).to include("All rights reserved")
      expect(response.body).not_to include("Regulamin współpracy")
      expect(response.body).not_to include("Wszelkie prawa zastrzeżone")
    end

    it "translates the signed-in menu" do
      sign_in user

      get root_path(locale: :en)

      expect(response.body).to include("My account")
      expect(response.body).to include("Log out")
      expect(response.body).not_to include("Moje konto")
      expect(response.body).not_to include("Wyloguj się")
    end

    it "translates the cart control" do
      get products_path(locale: :en)

      expect(response.body).to include(%(aria-label="Cart"))
      expect(response.body).not_to include(%(aria-label="Koszyk"))
    end
  end
end
