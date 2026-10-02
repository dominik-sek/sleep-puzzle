require "rails_helper"

RSpec.describe StagedMediaUpload, type: :model do
  it "never builds a disk path from a malformed stored token" do
    upload = described_class.new(token: "../../outside", target_type: "Product", filename: "intro.mp4",
                                 byte_size: 5, chunk_count: 1)

    expect(upload).not_to be_valid
    expect(upload.errors[:token]).to be_present
    expect { upload.directory }.to raise_error(ArgumentError, "Invalid upload token")
  end

  it "rejects a noninteger chunk index even when called outside the controller" do
    upload = described_class.new(token: "a" * 40, target_type: "Product", filename: "intro.mp4",
                                 byte_size: 5, chunk_count: 1)

    expect { upload.write_chunk("../0", StringIO.new("video")) }.to raise_error(ArgumentError, "Invalid chunk index")
  end
end
