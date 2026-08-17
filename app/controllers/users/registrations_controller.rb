# frozen_string_literal: true

# Devise's own registrations controller, with one thing changed: an account that
# has never had a password is not asked to confirm one.
#
# Google sign-ups have no password (see User#password_set?). Devise's default
# `update_resource` calls `update_with_password`, which requires `current_password`
# — so before this, a Google user could not change their email address or set a
# password at all: every save came back "Obecne hasło nie może być puste".
class Users::RegistrationsController < Devise::RegistrationsController
  protected

  def update_resource(resource, params)
    return super if resource.password_set?

    # Not `update_without_password`: that strips :password too, which would leave
    # a Google user unable to *set* a first password — the very thing they came
    # here to do. Dropping only :current_password lets the form work while the
    # model's own length and confirmation rules still apply.
    params.delete(:current_password)

    resource.update(params)
  end
end
