Rails.application.routes.draw do
  resources :documents do
    collection do
      get :refresh_from_google_drive
    end
  end
  resources :dashboard, only: ["index"]

  # Temporary route for testing environment variables
  get 'test/env', to: 'test#env_test'

  # Authentication routes
  get 'login', to: 'sessions#new'
  post 'login', to: 'sessions#create'
  delete 'logout', to: 'sessions#destroy'

  # OmniAuth callback
  get 'auth/:provider/callback', to: 'sessions#omniauth'
  post 'auth/:provider/callback', to: 'sessions#omniauth'

  # Google Drive OAuth2 callback
  get 'oauth2callback', to: 'documents#oauth_callback'

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "dashboard#index"
end
