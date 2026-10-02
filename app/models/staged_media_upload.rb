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
  TOKEN_PATTERN = /\A[0-9a-f]{40}\z/

  attr_readonly :token

  belongs_to :user
  validates :token, presence: true, uniqueness: true, format: { with: TOKEN_PATTERN }
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
    raise ArgumentError, "Invalid upload token" unless TOKEN_PATTERN.match?(token.to_s)

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

  def write_chunk(index, io)
    raise ArgumentError, "Invalid chunk index" unless index.is_a?(Integer) && index >= 0 && index < chunk_count

    FileUtils.mkdir_p(directory)
    temporary = directory.join("#{index}.tmp")
    begin
      File.open(temporary, "wb") do |file|
        IO.copy_stream(io, file, expected_chunk_size(index) + 1)
      end
      return false unless temporary.size == expected_chunk_size(index)

      File.rename(temporary, directory.join(index.to_s))
      true
    ensure
      File.delete(temporary) if temporary.exist?
    end
  end

  def assemble_blob
    return unless complete?

    assembled = directory.join("assembled")
    File.open(assembled, "wb") do |output|
      chunk_count.times do |index|
        File.open(directory.join(index.to_s), "rb") { |part| IO.copy_stream(part, output) }
      end
    end
    return unless assembled.size == byte_size

    File.open(assembled, "rb") do |file|
      content_type = Marcel::MimeType.for(file, name: filename)
      file.rewind
      ActiveStorage::Blob.create_and_upload!(io: file, filename: filename, content_type: content_type)
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
