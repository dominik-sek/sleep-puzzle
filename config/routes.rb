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
  resources :packages, only: [ :index, :show ]
  resources :dashboard, only: [ :index ]
  # looked up by token rather than id: the URL is handed to Paddle as the checkout
  # success redirect, so it shouldn't expose sequential ids
  resources :bookings, only: [ :index, :show, :create ], param: :token
  resources :products, only: [ :index, :show ]

  namespace :integrations do
    resource :google_calendar, only: [ :show, :destroy ], controller: "google_calendar" do
      get :connect, on: :collection
      get :callback, on: :collection
    end
  end
end
