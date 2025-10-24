Rails.application.routes.draw do
  # Root path
  root "home#index"
  
  # Authentication routes
  get    "/login",  to: "sessions#new",     as: :login
  post   "/login",  to: "sessions#create"
  delete "/logout", to: "sessions#destroy", as: :logout
  
  get  "/signup", to: "registrations#new",    as: :signup
  post "/signup", to: "registrations#create"
  
  # Customer reservation routes
  resources :reservations do
    collection do
      get :availability
    end
  end
  
  # Admin routes
  namespace :admin do
    get "/", to: "dashboard#index", as: :dashboard
    get "/calendar", to: "dashboard#calendar", as: :calendar
    
    resources :reservations
    resources :time_slots
    resources :tables
  end
  
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
