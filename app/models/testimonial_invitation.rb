# frozen_string_literal: true

# == Schema Information
#
# Table name: testimonial_invitations
#
#  id                        :bigint           not null, primary key
#  author                    :string
#  consented_at              :datetime
#  locale                    :string
#  quote                     :text
#  recipient_label           :string           not null
#  status                    :string           default("open"), not null
#  submitted_at              :datetime
#  token                     :string           not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  published_content_item_id :bigint
#
# Indexes
#
#  index_testimonial_invitations_on_published_content_item_id  (published_content_item_id)
#  index_testimonial_invitations_on_status                     (status)
#  index_testimonial_invitations_on_token                      (token) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (published_content_item_id => content_items.id) ON DELETE => nullify
#
class TestimonialInvitation < ApplicationRecord
  STATUSES = %w[open submitted approved declined].freeze

  belongs_to :published_content_item, class_name: "ContentItem", optional: true

  attribute :publication_consent, :boolean

  before_validation :ensure_token, on: :create

  validates :token, presence: true, uniqueness: true
  validates :recipient_label, presence: true, length: { maximum: 100 }
  validates :status, inclusion: { in: STATUSES }
  validates :quote, presence: true, length: { maximum: 2_000 }, if: :submitted_or_later?
  validates :author, presence: true, length: { maximum: 100 }, if: :submitted_or_later?
  validates :publication_consent, acceptance: { accept: true }, on: :submit

  scope :recent_first, -> { order(created_at: :desc) }

  def open?
    status == "open"
  end

  def submitted?
    status == "submitted"
  end

  def approved?
    status == "approved"
  end

  def declined?
    status == "declined"
  end

  def submit!(attributes, locale:)
    with_lock do
      return false unless open?

      assign_attributes(attributes.slice(:quote, :author, :publication_consent))
      self.quote = quote&.strip
      self.author = author&.strip
      self.locale = locale.to_s
      self.status = "submitted"
      self.consented_at = Time.current if publication_consent
      self.submitted_at = Time.current
      save(context: :submit)
    end
  end

  def approve!
    with_lock do
      return false unless submitted?

      item = ContentItem.new(
        collection_key: "testimonials.entries",
        position: (ContentItem.for_collection("testimonials.entries").maximum(:position) || 0) + 1
      )
      item.assign_value("quote", locale, quote)
      item.assign_value("author", locale, author)
      item.save!
      update!(status: "approved", published_content_item: item)
      true
    end
  end

  def decline!
    with_lock do
      return false unless submitted?

      update!(status: "declined")
      true
    end
  end

  private

  def submitted_or_later?
    status != "open"
  end

  def ensure_token
    self.token ||= SecureRandom.urlsafe_base64(32)
  end
end
