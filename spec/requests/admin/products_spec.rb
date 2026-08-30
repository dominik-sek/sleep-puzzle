require 'rails_helper'

RSpec.describe "Admin::Products", type: :request do
  include ActiveJob::TestHelper

  let(:admin) { User.create!(email: "owner@example.com", password: "password123", admin: true) }

  # overrides are merged into the record hash, e.g. product_params(kind: "audio_process")
  def product_params(overrides = {})
    {
      record: {
        paddle_price_id: "pri_456",
        kind: "bedtime_story",
        position: "1",
        published: "1",
        cdn_path: "/bajki/o-sowie.mp3",
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
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects a kind that is not one of the two the shop sells" do
      post admin_products_path, params: product_params(kind: "podcast")

      expect(response).to have_http_status(:unprocessable_content)
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

      expect(response).to have_http_status(:unprocessable_content)
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

      it "stages the file and hands it to a job rather than uploading in the request" do
        expect_any_instance_of(Net::HTTP).not_to receive(:request)

        post admin_products_path, params: product_params(audio: audio_upload)

        expect(response).to redirect_to(admin_products_path)
        expect(Product.last.audio_upload).to be_attached
        expect(ProductAudioUploadJob).to have_been_enqueued.with(Product.last)
      end

      it "keeps the file under the name the owner picked" do
        post admin_products_path, params: product_params(audio: audio_upload)

        expect(Product.last.audio_upload.filename.to_s).to eq("Nagranie Śpiącej Sowy.mp3")
      end

      it "says in the flash that the file is still going up" do
        post admin_products_path, params: product_params(audio: audio_upload)

        expect(flash[:notice]).to include("w tle")
      end

      it "lets a product be published in the same save as its upload" do
        params = product_params(audio: audio_upload, cdn_path: "", published: "1")

        expect { post admin_products_path, params: params }.to change(Product, :count).by(1)

        expect(Product.last).to be_published
        expect(Product.last.cdn_path).to be_blank
      end

      it "keeps a product whose file is still uploading out of the shop" do
        post admin_products_path, params: product_params(audio: audio_upload, cdn_path: "", published: "1")

        expect(Product.published).to be_empty
      end

      it "leaves the current path alone while the replacement uploads" do
        product = create_product(name: "Bajka o sowie", cdn_path: "/bajki/stare-nagranie.mp3")

        patch admin_product_path(product), params: { record: { audio: audio_upload } }

        expect(product.reload.cdn_path).to eq("/bajki/stare-nagranie.mp3")
        expect(product.audio_upload).to be_attached
      end

      it "ignores a path submitted alongside a file" do
        post admin_products_path, params: product_params(audio: audio_upload, cdn_path: "/bajki/gdzie-indziej.mp3")

        expect(Product.last.cdn_path).to be_blank
      end

      describe "what it still refuses on the spot" do
        it "refuses a file that is not audio" do
          expect { post admin_products_path, params: product_params(audio: audio_upload(filename: "okladka.png")) }
            .not_to change(Product, :count)

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).to include("mp3")
          expect(ProductAudioUploadJob).not_to have_been_enqueued
        end

        it "refuses an empty file" do
          post admin_products_path, params: product_params(audio: audio_upload(content: ""))

          expect(response.body).to include("pusty")
        end

        # what the owner typed is still on the screen to fix, not thrown away
        it "keeps the submitted fields on the re-rendered form" do
          post admin_products_path, params: product_params(audio: audio_upload(filename: "okladka.png"))

          expect(response.body).to include("Bajka o sowie", "The owl story")
        end
      end

      it "drops the staged file when the save fails anyway" do
        params = product_params(audio: audio_upload, length_minutes: "-5")

        expect { post admin_products_path, params: params }.not_to change(Product, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(ActiveStorage::Blob.count).to eq(0)
      end

      it "saves the rest of the product when no file was chosen" do
        params = product_params(audio: "", cdn_path: "", published: "0")

        expect { post admin_products_path, params: params }.to change(Product, :count).by(1)

        expect(Product.last.cdn_path).to be_blank
        expect(ProductAudioUploadJob).not_to have_been_enqueued
      end

      # The shop cannot offer something there is no file to deliver, so the
      # publish is refused rather than saved as a listing with no player.
      it "refuses to publish a product with no file" do
        params = product_params(audio: "", cdn_path: "", published: "1")

        expect { post admin_products_path, params: params }.not_to change(Product, :count)
        expect(response).to have_http_status(:unprocessable_content)
      end

      # The file reaches the server as a direct upload before the form is
      # submitted, which is what the progress bar measures; the form then carries
      # only the signed id of a blob that is already on disk.
      describe "a file that arrived as a direct upload" do
        def signed_id(filename: "Nagranie Śpiącej Sowy.mp3", content: "ID3 fake audio bytes")
          ActiveStorage::Blob.create_and_upload!(
            io: StringIO.new(content), filename: filename, content_type: "audio/mpeg"
          ).signed_id
        end

        it "attaches the blob the form points at and queues the transfer" do
          post admin_products_path, params: product_params(audio: signed_id, cdn_path: "")

          expect(response).to redirect_to(admin_products_path)
          expect(Product.last.audio_upload.filename.to_s).to eq("Nagranie Śpiącej Sowy.mp3")
          expect(ProductAudioUploadJob).to have_been_enqueued.with(Product.last)
        end

        it "offers the field as a direct upload" do
          get new_admin_product_path

          expect(response.body).to include("data-direct-upload-url")
        end

        # Judged from the blob's own metadata, so a 400 MB file is refused
        # without being read back off disk.
        it "refuses a blob whose name or size is wrong" do
          expect { post admin_products_path, params: product_params(audio: signed_id(filename: "okladka.png")) }
            .not_to change(Product, :count)

          expect(response.body).to include("mp3")
        end

        it "refuses an id that does not verify" do
          post admin_products_path, params: product_params(audio: "not-a-signed-id")

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).to include("Nie udało się odczytać")
        end
      end

      it "subscribes the catalogue and the form to the upload stream" do
        product = create_product

        get admin_products_path
        expect(response.body).to include("turbo-cable-stream-source")

        get edit_admin_product_path(product)
        expect(response.body).to include("turbo-cable-stream-source")
      end

      it "flags the row while the file is uploading, and after it failed" do
        post admin_products_path, params: product_params(audio: audio_upload, cdn_path: "")

        get admin_products_path
        expect(response.body).to include("Wgrywanie")

        Product.last.audio_upload.purge
        Product.last.update_column(:audio_upload_error, "Bunny odrzucił klucz dostępu.")

        get admin_products_path
        expect(response.body).to include("Błąd pliku")
      end

      it "stores where the file landed once the job runs" do
        stub_bunny_upload

        perform_enqueued_jobs do
          post admin_products_path, params: product_params(audio: audio_upload, cdn_path: "")
        end

        expect(Product.last.cdn_path).to match(%r{\A/bajki/nagranie-spiacej-sowy-[0-9a-f]{8}\.mp3\z})
        expect(Product.last.audio_upload).not_to be_attached
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
