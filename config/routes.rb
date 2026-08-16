Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks" }

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

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
  resources :products, only: [ :index, :show ]
  # one page that both shows the form and takes it, so there is no id to carry
  resource :contact, only: [ :show, :create ]
  # singular: there is one "about", so no id and no index. `controller:` keeps the
  # class singular too, the same way the google_calendar integration does below.
  resource :about, only: [ :show ], controller: "about"

  # staff-only; access is the `admin` boolean on users, granted with
  # `bin/rails 'admin:promote[email]'`
  namespace :admin do
    root "dashboard#index"
    resources :bookings, only: [ :index, :show ], param: :token
    resources :content_blocks, only: [ :index ] do
      patch :update, on: :collection
    end
    resources :content_items, only: [ :create, :destroy ]
    # the price list is shared by both catalogue screens, so refreshing it is one
    # endpoint that returns you to whichever page you asked from
    resource :paddle_prices, only: [ :update ]
    resources :packages, except: [ :show ]
    resources :products, except: [ :show ]
  end

  namespace :integrations do
    resource :google_calendar, only: [ :show, :destroy ], controller: "google_calendar" do
      get :connect, on: :collection
      get :callback, on: :collection
    end
  end
end
