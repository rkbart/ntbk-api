Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      # Authentication
      post "auth/register", to: "auth#register"
      post "auth/login", to: "auth#login"
      get "auth/me", to: "auth#me"
      patch "auth/me", to: "auth#update_profile"
      post "auth/refresh", to: "auth#refresh"

      # Tags (global, not nested under workspace)
      resources :tags, only: [ :index, :create, :destroy ]

      # Nested resources under workspace
      resources :workspaces, only: [ :index, :show, :create, :update ] do
        resources :folders, only: [ :index, :show, :create, :update, :destroy ]
        resources :documents, only: [ :index, :show, :create, :update, :destroy ] do
          member do
            post :archive
            post :restore
          end
        end
      end
    end
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
