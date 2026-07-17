Rails.application.routes.draw do
  # Devise routes for OmniAuth
  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks" }

  namespace :api do
    namespace :v1 do
      # Authentication
      post "auth/register", to: "auth#register"
      post "auth/login", to: "auth#login"
      get "auth/me", to: "auth#me"
      patch "auth/me", to: "auth#update_profile"
      post "auth/refresh", to: "auth#refresh"
      post "auth/google", to: "auth#google_callback"

      # Search
      get "search", to: "search#index"

      # Tags (global, not nested under workspace)
      resources :tags, only: [ :index, :create, :destroy ]

      # Nested resources under workspace
      resources :workspaces, only: [ :index, :show, :create, :update ] do
        resources :folders, only: [ :index, :show, :create, :update, :destroy ]
        resources :documents, only: [ :index, :show, :create, :update, :destroy ] do
          member do
            post :archive
            post :restore
            get :summary, to: "ai/summaries#show"
            post :summary, to: "ai/summaries#create"
          end

          resources :attachments, only: [ :index, :show, :create, :destroy ] do
            member do
              get :download, to: "attachments/download#show"
              get :preview, to: "attachments/preview#show"
            end
          end
        end
      end

      # AI features
      namespace :ai do
        # Embeddings
        resources :embeddings, only: [ :create ] do
          collection do
            post :search
            post :generate_workspace
          end
          member do
            post :similar
            post :generate
          end
        end

        # Chat
        resources :conversations, only: [ :index, :show, :create, :destroy ], controller: "chat"
        post "chat", to: "chat#send_message"
        post "chat/stream", to: "chat#send_message_stream"

        # Summaries
        resources :summaries, only: [ :create ] do
          collection do
            post :generate_workspace
          end
        end
      end
    end
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
