require 'rails_helper'

RSpec.describe "Admin::Products", type: :request do
  let(:admin) { User.create!(email: "owner@example.com", password: "password123", admin: true) }

  # overrides are merged into the record hash, e.g. product_params(kind: "audio_process")
  def product_params(overrides = {})
    {
      record: {
        paddle_price_id: "pri_456",
        kind: "bedtime_story",
        position: "1",
        published: "1",
        translations: {
          "name" => { "pl" => "Bajka o sowie", "en" => "The owl story" },
          "description" => { "pl" => "Kojąca bajka na dobranoc", "en" => "" }
        }
      }.deep_merge(overrides)
    }
  end

  describe "access" do
    it "redirects a signed-in non-admin away" do
      sign_in User.create!(email: "customer@example.com", password: "password123")

      get admin_products_path

      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET /admin/products" do
    before { sign_in admin }

    it "lists products with their kind" do
      create_product(name: "Bajka o sowie", kind: :bedtime_story)
      create_product(name: "Wieczorny rytuał", kind: :audio_process)

      get admin_products_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Bajka o sowie", "Bajka na dobranoc", "Wieczorny rytuał", "Audioproces")
    end
  end

  describe "GET /admin/products/new and /edit" do
    before { sign_in admin }

    it "renders the new form" do
      get new_admin_product_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Bajka na dobranoc", "Audioproces")
    end

    it "renders the edit form" do
      get edit_admin_product_path(create_product(name: "Bajka o sowie"))

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Bajka o sowie")
    end
  end

  describe "POST /admin/products" do
    before { sign_in admin }

    it "creates a product with both languages" do
      expect { post admin_products_path, params: product_params }.to change(Product, :count).by(1)

      product = Product.last
      expect(I18n.with_locale(:pl) { product.name }).to eq("Bajka o sowie")
      expect(I18n.with_locale(:en) { product.name }).to eq("The owl story")
      expect(product).to be_bedtime_story
      expect(response).to redirect_to(admin_products_path)
    end

    it "re-renders with errors when the name is missing" do
      params = product_params(translations: { "name" => { "pl" => "", "en" => "" } })

      expect { post admin_products_path, params: params }.not_to change(Product, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects a kind that is not one of the two the shop sells" do
      post admin_products_path, params: product_params(kind: "podcast")

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Product.count).to eq(0)
    end

    it "stores the Bunny path, normalised" do
      post admin_products_path, params: product_params(cdn_path: "bajki/o-sowie.mp3")

      expect(Product.last.cdn_path).to eq("/bajki/o-sowie.mp3")
    end

    # better caught here, where the owner can fix the filename, than as a 403
    # from Bunny the first time a buyer presses play
    it "re-renders when the path would not survive a URL intact" do
      post admin_products_path, params: product_params(cdn_path: "/bajki/o sowie.mp3")

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Product.count).to eq(0)
    end
  end

  describe "PATCH /admin/products/:id" do
    before { sign_in admin }

    it "updates the record" do
      product = create_product(name: "Bajka o sowie")

      patch admin_product_path(product),
            params: { record: { paddle_price_id: "pri_456", kind: "audio_process", published: "0",
                                translations: { "name" => { "en" => "Evening ritual" } } } }

      product.reload
      expect(product).to be_audio_process
      expect(I18n.with_locale(:en) { product.name }).to eq("Evening ritual")
      expect(I18n.with_locale(:pl) { product.name }).to eq("Bajka o sowie")
    end
  end

  describe "DELETE /admin/products/:id" do
    before { sign_in admin }

    it "deletes the product" do
      product = create_product

      expect { delete admin_product_path(product) }.to change(Product, :count).by(-1)
    end
  end

  # The owner uploads the recording here rather than through Bunny's own
  # dashboard, so the product and the file it points at are saved in one action.
  describe "uploading the audio" do
    before { sign_in admin }

    context "with the storage zone configured" do
      before { with_bunny_storage }

      it "offers an uploader instead of a path to type" do
        get new_admin_product_path

        expect(response.body).to include('type="file"', 'name="record[audio]"')
        expect(response.body).not_to include('name="record[cdn_path]"')
      end

      it "sends the file to Bunny and stores where it landed" do
        stub_bunny_upload

        post admin_products_path, params: product_params(audio: audio_upload)

        expect(response).to redirect_to(admin_products_path)
        expect(Product.last.cdn_path).to match(%r{\A/bajki/nagranie-spiacej-sowy-[0-9a-f]{8}\.mp3\z})
      end

      it "files it under the folder for the kind chosen on the form" do
        stub_bunny_upload

        post admin_products_path, params: product_params(kind: "audio_process", audio: audio_upload)

        expect(Product.last.cdn_path).to start_with("/audioprocesy/")
      end

      it "replaces the file an existing product points at" do
        stub_bunny_upload
        product = create_product(name: "Bajka o sowie", cdn_path: "/bajki/stare-nagranie.mp3")

        patch admin_product_path(product), params: { record: { audio: audio_upload } }

        expect(product.reload.cdn_path).not_to eq("/bajki/stare-nagranie.mp3")
      end

      # An edit that only swaps the file submits no kind, so the folder has to
      # come off the record rather than out of the form.
      it "takes the folder from the saved kind when the form does not resend it" do
        stub_bunny_upload
        product = create_product(name: "Wieczorny rytuał", kind: :audio_process)

        patch admin_product_path(product), params: { record: { audio: audio_upload } }

        expect(product.reload.cdn_path).to start_with("/audioprocesy/")
      end

      # The upload is the source of truth for where the file is now, so it wins
      # over anything the submitted form happened to be carrying.
      it "ignores a path submitted alongside a file" do
        stub_bunny_upload

        post admin_products_path, params: product_params(audio: audio_upload, cdn_path: "/bajki/gdzie-indziej.mp3")

        expect(Product.last.cdn_path).not_to eq("/bajki/gdzie-indziej.mp3")
      end

      # Uploading before saving is what makes this possible: a product saved with
      # no audio would have looked like a success and had no player.
      it "re-renders with the reason rather than saving a product with no audio" do
        stub_bunny_upload(code: 401, body: "unauthorized")

        expect { post admin_products_path, params: product_params(audio: audio_upload) }
          .not_to change(Product, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("BUNNY_STORAGE_PASSWORD")
      end

      # what the owner typed is still on the screen to fix, not thrown away
      it "keeps the submitted fields on the re-rendered form" do
        stub_bunny_upload(code: 500, body: "boom")

        post admin_products_path, params: product_params(audio: audio_upload)

        expect(response.body).to include("Bajka o sowie", "The owl story")
      end

      it "saves the rest of the product when no file was chosen" do
        expect_any_instance_of(Net::HTTP).not_to receive(:request)

        expect { post admin_products_path, params: product_params(audio: "") }
          .to change(Product, :count).by(1)

        expect(Product.last.cdn_path).to be_nil
      end
    end

    # Local development, or a deploy that lost the credentials. The path stays
    # typeable so the field is not simply dead, and the reason the uploader is
    # missing is on the screen rather than in a log.
    context "without the storage zone configured" do
      it "falls back to the path field and says why" do
        get new_admin_product_path

        expect(response.body).to include('name="record[cdn_path]"', "BUNNY_STORAGE_ZONE")
        expect(response.body).not_to include('name="record[audio]"')
      end
    end
  end
end
