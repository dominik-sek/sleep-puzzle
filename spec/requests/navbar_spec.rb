require 'rails_helper'

RSpec.describe "Navbar", type: :request do
  let(:user) { User.create!(email: "customer@example.com", password: "password123") }

  describe "the cart control" do
    it "is an icon rather than an emoji" do
      get root_path

      expect(response.body).to include(%(aria-label="Koszyk"))
      expect(response.body).not_to include("🧺")
    end

    it "shows no count bubble on an empty cart" do
      get root_path

      expect(response.body).not_to include("bg-accent px-1")
    end

    it "shows the count once something is in there" do
      post cart_items_path, params: { product_id: create_product.id }

      get root_path

      expect(response.body).to include("bg-accent px-1")
    end
  end

  describe "the profile dropdown" do
    before { sign_in user }

    # "fit" is not a Tailwind class, so it resolved to nothing and the panel
    # collapsed to the width of its longest label
    it "has a real width class on the panel" do
      get root_path

      # asserted as the exact rendered attribute: the old value was "fit", which is
      # not a Tailwind class, so it resolved to nothing and the panel collapsed to
      # the width of its longest label
      expect(response.body).to include(%(class="grid gap-2 p-2 w-56 grid-cols-1"))
    end

    # a bare <hr> takes the browser default, which on a dark panel reads as a
    # bright white rule
    it "separates with a hairline in the panel's own palette" do
      get root_path

      expect(response.body).to include(%(class="my-1 h-px bg-border"))
      expect(response.body).not_to include("<hr/>")
      expect(response.body).not_to include("<hr>")
    end

    # asserted by what the panel contains rather than by counting the shared class
    # across the page: the language menu draws its rows from the same helper, so a
    # global count says nothing about this dropdown
    it "renders the account and sign-out rows through the shared classes" do
      get root_path

      # `<div id=` and not just `id=`: the trigger carries data-content-id with the
      # same value, and anchoring on that matches the button instead of the panel
      panel = response.body[/<div id="profile-content".{0,2000}/m]

      expect(panel).to include("flex w-full items-center gap-2.5")
      expect(panel).to include(%(href="#{dashboard_index_path}"))
      expect(panel).not_to include(%(href="#{admin_root_path}"))
    end

    it "gives an admin the panel link too" do
      sign_in User.create!(email: "boss@example.com", password: "password123", admin: true)

      get root_path

      expect(response.body).to include(%(href="#{admin_root_path}"))
    end

    it "keeps sign-out a DELETE while the rest are plain links" do
      get root_path

      expect(response.body).to include(%(href="#{dashboard_index_path}"))
      expect(response.body).to include(destroy_user_session_path)
    end
  end
end
