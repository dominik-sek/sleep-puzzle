class BlankPasswordForOauthUsers < ActiveRecord::Migration[8.1]
  # Google sign-ups were given `Devise.friendly_token` as a password — a random
  # string the account holder was never told. It let them in through Google and
  # nowhere else, but it also made `encrypted_password` look set, which is why
  # /users/edit demanded a "current password" they could not possibly know and
  # refused every change they tried to make.
  #
  # Blanking it makes "has this account ever set a password?" answerable
  # (User#password_set?). Nothing is lost: the value was never usable by anyone.
  #
  # Irreversible on purpose — the old random strings are not worth restoring, and
  # anyone affected can set a real password from the account screen or via
  # "forgot password".
  def up
    User.where.not(provider: nil).where.not(encrypted_password: "").find_each do |user|
      user.update_columns(encrypted_password: "")
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
