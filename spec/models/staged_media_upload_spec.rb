require "rails_helper"

# == Schema Information
#
# Table name: staged_media_uploads
#
#  id           :bigint           not null, primary key
#  byte_size    :bigint           not null
#  chunk_count  :integer          not null
#  completed_at :datetime
#  filename     :string           not null
#  target_type  :string           not null
#  token        :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  target_id    :bigint           not null
#  user_id      :bigint           not null
#
# Indexes
#
#  index_staged_media_uploads_on_target_type_and_target_id  (target_type,target_id)
#  index_staged_media_uploads_on_token                      (token) UNIQUE
#  index_staged_media_uploads_on_user_id                    (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
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
