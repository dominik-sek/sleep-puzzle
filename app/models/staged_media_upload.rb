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
class StagedMediaUpload < ApplicationRecord
  CHUNK_BYTES = 64.megabytes
  MAX_AUDIO_BYTES = 250.megabytes
  MAX_VIDEO_BYTES = 1.gigabyte

  belongs_to :user
  validates :token, presence: true, uniqueness: true
  validates :filename, presence: true
  validates :target_type, inclusion: { in: %w[Product AudioChapter] }
  validates :byte_size, numericality: { only_integer: true, greater_than: 0 }
  validates :chunk_count, numericality: { only_integer: true, greater_than: 0 }
  validate :allowed_file

  before_validation :set_token, on: :create

  def target
    target_type.constantize.find_by(id: target_id)
  end

  def video?
    target_type == "Product"
  end

  def extension
    File.extname(filename).downcase.delete_prefix(".")
  end

  def directory
    Rails.root.join("storage", "staged_media", token)
  end

  def expected_chunk_size(index)
    [ CHUNK_BYTES, byte_size - index * CHUNK_BYTES ].min
  end

  def complete?
    (0...chunk_count).all? do |index|
      path = directory.join(index.to_s)
      path.file? && path.size == expected_chunk_size(index)
    end
  end

  def cleanup!
    FileUtils.remove_entry(directory) if directory.exist?
    destroy!
  end

  private

  def set_token
    self.token ||= SecureRandom.hex(20)
  end

  def allowed_file
    extensions = video? ? %w[mp4 mov] : BunnyStorageService::ALLOWED_EXTENSIONS
    limit = video? ? MAX_VIDEO_BYTES : MAX_AUDIO_BYTES
    errors.add(:filename, "ma niedozwolony format") unless extensions.include?(extension)
    errors.add(:byte_size, "przekracza limit") if byte_size.to_i > limit
    errors.add(:chunk_count, "nie odpowiada rozmiarowi") if byte_size.to_i.positive? && chunk_count != (byte_size.to_f / CHUNK_BYTES).ceil
  end
end
