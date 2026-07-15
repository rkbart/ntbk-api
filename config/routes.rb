Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      # Authentication
      post "auth/register", to: "auth#register"
      post "auth/login", to: "auth#login"
      get "auth/me", to: "auth#me"
      patch "auth/me", to: "auth#update_profile"
      post "auth/refresh", to: "auth#refresh"
    end
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
