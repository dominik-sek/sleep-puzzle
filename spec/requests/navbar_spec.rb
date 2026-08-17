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

    it "renders every row through the one shared set of classes" do
      get root_path

      # account, sign out — and the admin row only for an admin
      expect(response.body.scan("flex w-full items-center gap-2.5").size).to eq(2)
    end

    it "gives an admin the panel link too" do
      sign_in User.create!(email: "boss@example.com", password: "password123", admin: true)

      get root_path

      expect(response.body.scan("flex w-full items-center gap-2.5").size).to eq(3)
      expect(response.body).to include(%(href="#{admin_root_path}"))
    end

    it "keeps sign-out a DELETE while the rest are plain links" do
      get root_path

      expect(response.body).to include(%(href="#{dashboard_index_path}"))
      expect(response.body).to include(destroy_user_session_path)
    end
  end
end
