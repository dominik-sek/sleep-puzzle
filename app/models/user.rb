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
class User < ApplicationRecord

  pay_customer default_payment_processor: :paddle_billing

  has_many :bookings, dependent: :restrict_with_error
  has_many :orders, dependent: :restrict_with_error
  # what the dashboard's audio library reads: every product this user has paid
  # for, deduplicated, so buying the same story twice lists it once
  has_many :purchased_products, -> { distinct.merge(Order.paid) },
           through: :orders, source: :products

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: %i[google_oauth2]


  # Whether this account can be signed into with a password at all.
  #
  # False for a Google sign-up that has never set one, which is what lets
  # Users::RegistrationsController accept changes without asking for a "current
  # password" the holder has no way of knowing.
  def password_set?
    encrypted_password.present?
  end

  # Digital files are bought once and kept: owning one is what blocks buying it
  # again, in the shop's button, in the cart and at checkout.
  def purchased?(product)
    purchased_products.exists?(id: product.id)
  end

  def initials
    [ first_name, last_name ].map { |n| n&.first&.upcase }.compact.join
  end

  def full_name
    [ first_name, last_name ].compact.join(" ").presence
  end

  # Pay reads this when building the Paddle customer. Only Google sign-ups carry a
  # first/last name, so without the fallback a Devise registration sends name: ""
  # and Paddle rejects the customer.
  def pay_customer_name
    full_name || email
  end

  # Validatable insists on a password whenever a record is created. A Google
  # sign-up arrives without one by design, so that single case is excused — and
  # only that case: the moment a password *is* being set, `super` takes over and
  # the length and confirmation rules apply as normal.
  #
  # Narrow on purpose. Returning true whenever no password was submitted would
  # demand one on every update, which is exactly how an email-only change breaks.
  def password_required?
    return false if provider.present? && password.blank? && password_confirmation.blank?

    super
  end

  def self.from_omniauth(access_token)
    data = access_token.info
    user = User.where(email: data["email"]).first

    if user
      user.update(avatar_url: data["image"])
    else
      user = User.create(
        first_name: data["first_name"],
        last_name: data["last_name"],
        email: data["email"],
        avatar_url: data["image"],
        # deliberately no password: a random one the holder is never told is not a
        # password, and storing one made /users/edit ask them to confirm it. They
        # can set a real one later from the account screen.
        provider: access_token.provider,
        uid: access_token.uid
      )
    end
    user
  end
end
