Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  devise_for :users, controllers: {
    omniauth_callbacks: "users/omniauth_callbacks",
    # only overrides #update_resource, so an account with no password (a Google
    # sign-up) is not asked to confirm one
    registrations: "users/registrations"
  }

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Polish keeps the bare paths it has always had; English is the same route under
  # an /en prefix. Constrained to /en/ rather than /pl|en/ on purpose: with only
  # the non-default locale ever in a URL there is one canonical address per page,
  # instead of /about and /pl/about both answering.
  #
  # Only the public pages are in here. Devise, the admin panel and the OAuth
  # callbacks stay outside it, because their URLs are registered with Google and
  # with Paddle and must not move.
  scope "(:locale)", locale: /en/ do
    # Defines the root path route ("/")
    root "home#index"
    # one page: each card carries everything a package has to say, so there is
    # no per-package page to link to
    resources :packages, only: [ :index ]
    resources :dashboard, only: [ :index ]
    # looked up by token rather than id: the URL is handed to Paddle as the checkout
    # success redirect, so it shouldn't expose sequential ids
    resources :bookings, only: [ :index, :show, :create ], param: :token do
      # the browser reporting that the Paddle overlay was closed without paying
      delete :abandon, on: :member
    end
    resources :products, only: [ :index, :show ] do
      # what a buyer's player points at: it authorises, then redirects to a
      # freshly signed CDN URL. A member route rather than a nested resource
      # because there is only ever one file per product
      get :stream, on: :member

      # deliberately outside the authenticate_user! that guards :stream - the
      # whole point of a sample is that someone who has not bought anything, and
      # may not have an account, can hear it. It signs the preview's own path,
      # never the full recording's.
      get :preview, on: :member
    end
    # singular: one cart per visitor, kept in the session, so there is no id to
    # carry. Its lines are addressed by product id - there are no cart item rows.
    resource :cart, only: [ :show ], controller: "cart" do
      delete :clear, on: :collection
    end
    # no :update - a digital file has no quantity to change, so a line is only ever
    # added or removed
    resources :cart_items, only: [ :create, :destroy ], param: :product_id
    # by token for the same reason bookings are: the URL is handed to Paddle as the
    # checkout success redirect
    resources :orders, only: [ :create, :show ], param: :token do
      delete :abandon, on: :member
    end
    # one page that both shows the form and takes it, so there is no id to carry
    resource :contact, only: [ :show, :create ]
    # create only: the form lives on the home page, and everything after the
    # address is handed over - the confirmation, the list, the unsubscribe - is
    # Brevo's, so there is nothing here to show, edit or destroy
    resource :newsletter_subscription, only: [ :create ]
    # singular: there is one "about", so no id and no index. `controller:` keeps the
    # class singular too, the same way the google_calendar integration does below.
    resource :about, only: [ :show ], controller: "about"
    # singular for the same reason as `about` above: there is one regulamin. The
    # `controller:` keeps the class name singular too, matching the file.
    resource :terms, only: [ :show ], controller: "terms"
  end

  # staff-only; access is the `admin` boolean on users, granted with
  # `bin/rails 'admin:promote[email]'`
  namespace :admin do
    root "dashboard#index"
    resources :bookings, only: [ :index, :show ], param: :token
    # by token like the public side, so the panel and a customer's own link name
    # the same order the same way
    resources :orders, only: [ :index, :show ], param: :token
    resources :content_blocks, only: [ :index ] do
      patch :update, on: :collection
    end
    resources :content_items, only: [ :create, :destroy ]
    # the price list is shared by both catalogue screens, so refreshing it is one
    # endpoint that returns you to whichever page you asked from
    resource :paddle_prices, only: [ :update ]
    resources :packages, except: [ :show ]
    resources :products, except: [ :show ]

    # Solid Queue dashboard. Inside the admin namespace so it is gated by the
    # same admin flag as everything else here - see the initializer.
    mount MissionControl::Jobs::Engine, at: "/jobs"

    # Postgres dashboard. PgHero's engine takes no base controller class the way
    # Mission Control does, so the admin flag is enforced on the route itself -
    # anyone else matches no route at all, which is a 404 in production rather
    # than a redirect. Its own HTTP basic auth stays off for the same reason it
    # is off for /admin/jobs: one password, and it is the one you signed in with.
    authenticate :user, ->(user) { user.admin? } do
      mount PgHero::Engine, at: "/db"
    end
  end

  namespace :integrations do
    resource :google_calendar, only: [ :show, :update, :destroy ], controller: "google_calendar" do
      get :connect, on: :collection
      get :callback, on: :collection
    end
  end
end
