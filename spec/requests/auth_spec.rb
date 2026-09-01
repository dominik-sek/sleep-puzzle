require 'rails_helper'

RSpec.describe "Auth screens", type: :request do
  let(:user) { User.create!(email: "customer@example.com", password: "password123") }

  # the whole point of the pass: every one of these shipped as English scaffolding
  describe "Polish copy" do
    it "is on the sign-in screen" do
      get new_user_session_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Zaloguj się")
      expect(response.body).to include("Adres e-mail")
      expect(response.body).to include("Hasło")
      expect(response.body).not_to include("Log in")
      expect(response.body).not_to include("Enter password")
    end

    it "is on the sign-up screen" do
      get new_user_registration_path

      expect(response.body).to include("Załóż konto")
      expect(response.body).to include("Powtórz hasło")
      expect(response.body).not_to include("Sign up")
    end

    it "is on the forgotten-password screen" do
      get new_user_password_path

      expect(response.body).to include("Nie pamiętasz hasła?")
      expect(response.body).to include("Wyślij link")
      expect(response.body).not_to include("Send me password reset instructions")
    end

    it "is on the reset screen the mail links to" do
      token = user.send_reset_password_instructions

      get edit_user_password_path(reset_password_token: token)

      expect(response.body).to include("Ustaw nowe hasło")
      expect(response.body).not_to include("Change your password")
    end

    it "is on the account screen" do
      sign_in user

      get edit_user_registration_path

      expect(response.body).to include("Dane konta")
      expect(response.body).to include("Obecne hasło")
      expect(response.body).not_to include("Edit User")
      expect(response.body).not_to include("Cancel my account")
    end
  end

  describe "English" do
    it "follows the locale onto the auth screens" do
      get new_user_session_path(locale: :en)

      expect(response.body).to include("Log in")
      expect(response.body).to include("Email address")
      expect(response.body).to include("Continue with Google")
      # the card's own Polish copy is gone; the navbar's is not, because its labels
      # are still hardcoded Polish - see the README roadmap
      expect(response.body).not_to include("Adres e-mail")
    end
  end

  describe "the Google button" do
    it "carries Google's own mark, not just text" do
      get new_user_session_path

      expect(response.body).to include("Kontynuuj z Google")
      expect(response.body).to include("#4285F4")
    end

    # the OAuth handshake is a full-page redirect off-site; Turbo would try to
    # fetch it and fail
    it "opts out of Turbo" do
      get new_user_session_path

      expect(response.body).to include("data-turbo=\"false\"")
    end

    it "posts to the provider's authorize path" do
      get new_user_session_path

      expect(response.body).to include(user_google_oauth2_omniauth_authorize_path)
    end

    it "is offered on sign-up too, not only sign-in" do
      get new_user_registration_path

      expect(response.body).to include("Kontynuuj z Google")
    end
  end

  describe "validation errors" do
    it "renders them in Polish, in the app's own panel" do
      post user_registration_path, params: { user: { email: "", password: "x" } }

      expect(response.body).to include("Nie udało się zapisać")
      expect(response.body).to include("error_explanation")
      expect(response.body).not_to include("prohibited this user from being saved")
    end
  end

  # A Google sign-up has no password, and Devise's default update_resource insists
  # on a "current password" to save anything - so before this, such an account could
  # not change its email or set a password at all.
  describe "an account created through Google" do
    let(:google_user) do
      User.create!(email: "g@example.com", provider: "google_oauth2", uid: "123",
                   first_name: "Karola")
    end

    it "is created without a password at all" do
      expect(google_user).to be_persisted
      expect(google_user).not_to be_password_set
    end

    it "cannot be signed into with a password" do
      expect(google_user.valid_password?("anything")).to be(false)
    end

    it "is not asked for a current password it cannot know" do
      sign_in google_user

      get edit_user_registration_path

      expect(response.body).not_to include("Obecne hasło")
      expect(response.body).to include("Ustaw hasło")
    end

    it "can change its email without one" do
      sign_in google_user

      patch user_registration_path, params: { user: { email: "new@example.com" } }

      expect(google_user.reload.email).to eq("new@example.com")
    end

    it "can set a first password without one" do
      sign_in google_user

      patch user_registration_path,
            params: { user: { email: google_user.email, password: "sekretne123",
                              password_confirmation: "sekretne123" } }

      expect(google_user.reload).to be_password_set
      expect(google_user.valid_password?("sekretne123")).to be(true)
    end

    # the exemption is for accounts with no password, not for Google accounts
    # forever - once one is set, confirming it is required again
    it "is asked to confirm once it has a password" do
      google_user.update!(password: "sekretne123", password_confirmation: "sekretne123")
      sign_in google_user

      get edit_user_registration_path
      expect(response.body).to include("Obecne hasło")

      patch user_registration_path, params: { user: { email: "new@example.com" } }
      expect(google_user.reload.email).to eq("g@example.com")
    end

    it "still validates the password it is setting" do
      sign_in google_user

      patch user_registration_path,
            params: { user: { email: google_user.email, password: "krotkie",
                              password_confirmation: "inne" } }

      expect(google_user.reload).not_to be_password_set
      expect(response.body).to include("error_explanation")
    end
  end

  # the exemption must not leak into ordinary accounts
  describe "an ordinary account" do
    it "still has to confirm its current password to change its email" do
      sign_in user

      patch user_registration_path, params: { user: { email: "new@example.com" } }

      expect(user.reload.email).to eq("customer@example.com")
      expect(response.body).to include("Obecne hasło")
    end

    it "can change its email with the current password" do
      sign_in user

      patch user_registration_path,
            params: { user: { email: "new@example.com", current_password: "password123" } }

      expect(user.reload.email).to eq("new@example.com")
    end
  end

  describe "flashes" do
    it "signs out in Polish" do
      sign_in user

      delete destroy_user_session_path
      follow_redirect!

      expect(response.body).to include("Wylogowano")
    end

    it "asks an anonymous visitor to sign in, in Polish" do
      get dashboard_index_path
      follow_redirect!

      expect(response.body).to include("Zaloguj się lub załóż konto")
    end
  end

  # The packages page hands the chosen package to /bookings as a query param, and
  # /bookings is gated. Before this, after_sign_in_path_for returned the dashboard
  # unconditionally, so signing in at that wall threw the choice away and left the
  # visitor on an empty dashboard with no route back.
  describe "returning to the blocked page after signing in" do
    it "sends the visitor back to the package they picked" do
      get bookings_path(package_id: 42)
      expect(response).to redirect_to(new_user_session_path)

      post user_session_path, params: {
        user: { email: user.email, password: "password123" }
      }

      expect(response).to redirect_to(bookings_path(package_id: 42))
    end

    it "still lands on the dashboard when nothing was blocked" do
      post user_session_path, params: {
        user: { email: user.email, password: "password123" }
      }

      expect(response).to redirect_to(dashboard_index_path)
    end
  end
end
