Rails.application.routes.draw do
  # ActionMailbox routes for inbound email processing
  mount ActionMailbox::Engine => "/rails/action_mailbox"

  resources :mailing_lists do
    member do
      post :add_member
      delete :remove_member
      get :broadcast
      post :send_broadcast
    end
  end
  resources :users, only: [ :index, :edit, :update, :destroy ]
  resources :tasks, without: [ :show ] do
    member do
      patch :prioritize
      patch :move_to_backlog
      patch :reorder
    end
  end
  resources :posts, only: [ :create, :update, :destroy ] do
    resources :likes, only: [ :create, :destroy ]
    resources :comments, only: [ :create, :destroy ] do
      resources :likes, only: [ :create, :destroy ]
    end
  end

  resources :discussion_topics do
    resources :topic_comments, only: [ :create, :destroy ] do
      resources :likes, only: [ :create, :destroy ]
    end
    resources :likes, only: [ :create, :destroy ]
  end
  resources :documents do
    collection do
      get :refresh_from_google_drive
    end
  end
  resources :dashboard, only: [ "index" ] do
    collection do
      post :refresh_drive_files
    end
  end

  resources :calendar, only: [ "index" ] do
    collection do
      get "show_event/:event_id", action: :show_event, as: :show_event
    end
  end
  resources :calendar_events, only: [ :new, :create, :show, :edit, :update, :destroy ] do
    collection do
      post :import_from_google
      get :edit, path: "edit_google/:google_event_id", action: :edit, as: :edit_google
      delete :destroy, path: "delete_google/:google_event_id", action: :destroy, as: :delete_google
    end
  end
  resources :calendar_shares, only: [ :create ] do
    collection do
      get :success
    end
  end

  resources :drive_shares, only: [ :create, :index ] do
    collection do
      get :success
    end
  end


  # Authentication routes
  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  # Invitation routes
  resources :invitations, only: [ :new, :create, :index ] do
    member do
      get :accept
    end
  end

  # OmniAuth callback
  get "auth/:provider/callback", to: "sessions#omniauth"
  post "auth/:provider/callback", to: "sessions#omniauth"

  # Google Drive OAuth2 callback
  get "oauth2callback", to: "documents#oauth_callback"

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
