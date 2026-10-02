require "rails_helper"

RSpec.describe "Admin staged media uploads", type: :request do
  include ActiveJob::TestHelper

  let(:admin) { User.create!(email: "admin@example.com", password: "password123", admin: true) }
  let(:product) { create_product(kind: :audio_process) }

  before do
    sign_in admin
    with_bunny_storage
  end

  it "accepts chunks, retries a chunk, assembles the file and queues processing" do
    chapter = product.audio_chapters.first
    post admin_staged_media_uploads_path, params: {
      target_type: "AudioChapter", target_id: chapter.id, filename: "new.mp3",
      byte_size: 6, chunk_count: 1
    }
    expect(response).to have_http_status(:ok)
    id = response.parsed_body.fetch("id")
    url = chunk_admin_staged_media_upload_path(id, index: 0)

    put url, params: "wrong!", headers: { "CONTENT_TYPE" => "application/octet-stream" }
    expect(response).to have_http_status(:no_content)
    put url, params: "audio!", headers: { "CONTENT_TYPE" => "application/octet-stream" }
    expect(response).to have_http_status(:no_content)

    expect { post complete_admin_staged_media_upload_path(id) }
      .to have_enqueued_job(AudioChapterUploadJob)
    expect(chapter.reload.audio_upload).to be_attached
    expect(chapter.audio_upload.download).to eq("audio!")
    expect(StagedMediaUpload.find_by(id: id)).to be_nil
  end

  it "rejects an oversized trailer before receiving any chunks" do
    post admin_staged_media_uploads_path, params: {
      target_type: "Product", target_id: product.id, filename: "intro.mp4",
      byte_size: StagedMediaUpload::MAX_VIDEO_BYTES + 1, chunk_count: 17
    }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(StagedMediaUpload.count).to eq(0)
  end

  it "queues trailer preparation after assembling a video" do
    post admin_staged_media_uploads_path, params: {
      target_type: "Product", target_id: product.id, filename: "intro.mov",
      byte_size: 5, chunk_count: 1
    }
    id = response.parsed_body.fetch("id")
    put chunk_admin_staged_media_upload_path(id, index: 0), params: "video",
        headers: { "CONTENT_TYPE" => "application/octet-stream" }

    expect { post complete_admin_staged_media_upload_path(id) }
      .to have_enqueued_job(ProductTrailerUploadJob)
    expect(product.reload.trailer_upload).to be_attached
  end

  it "does not allow another admin to write to an upload session" do
    upload = StagedMediaUpload.create!(user: admin, target_type: "Product", target_id: product.id,
                                       filename: "intro.mp4", byte_size: 5, chunk_count: 1)
    sign_out admin
    sign_in User.create!(email: "other-admin@example.com", password: "password123", admin: true)

    put chunk_admin_staged_media_upload_path(upload, index: 0), params: "video",
        headers: { "CONTENT_TYPE" => "application/octet-stream" }
    expect(response).to have_http_status(:not_found)
  end

  it "rejects chunk indexes outside the declared range" do
    upload = StagedMediaUpload.create!(user: admin, target_type: "Product", target_id: product.id,
                                       filename: "intro.mp4", byte_size: 5, chunk_count: 1)

    put chunk_admin_staged_media_upload_path(upload, index: 1), params: "video",
        headers: { "CONTENT_TYPE" => "application/octet-stream" }
    expect(response).to have_http_status(:unprocessable_content)
    expect(upload.directory.exist?).to be(false)
  end
end
