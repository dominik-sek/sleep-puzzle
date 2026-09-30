require 'rails_helper'

# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  admin                  :boolean          default(FALSE), not null
#  avatar_url             :string
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  first_name             :string
#  last_name              :string
#  provider               :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  uid                    :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#
RSpec.describe User, type: :model do
  describe ".from_omniauth" do
    def google_auth(email:, image: nil)
      OmniAuth::AuthHash.new(
        provider: "google_oauth2", uid: "google-123",
        info: { email: email, first_name: "Karola", last_name: "Testowa", image: image }
      )
    end

    it "keeps an existing avatar when Google omits the picture" do
      user = User.create!(email: "karola@example.com", password: "password123",
                          avatar_url: "https://example.com/previous.jpg")

      expect(described_class.from_omniauth(google_auth(email: user.email))).to eq(user)
      expect(user.reload.avatar_url).to eq("https://example.com/previous.jpg")
    end

    it "updates the avatar when Google provides a new picture" do
      user = User.create!(email: "karola@example.com", password: "password123",
                          avatar_url: "https://example.com/previous.jpg")

      described_class.from_omniauth(google_auth(email: user.email, image: "https://example.com/current.jpg"))

      expect(user.reload.avatar_url).to eq("https://example.com/current.jpg")
    end

    it "creates a Google account without an avatar when no picture is available" do
      user = described_class.from_omniauth(google_auth(email: "new@example.com"))

      expect(user).to be_persisted
      expect(user.avatar_url).to be_nil
    end
  end
end
