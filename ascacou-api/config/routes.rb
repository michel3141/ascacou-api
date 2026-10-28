Rails.application.routes.draw do
  scope path: "/api/v1", defaults: { format: :jsonapi } do
    resources :users, only: %i[show create update]
    resources :rooms, only: %i[index show create update]
    resources :games, only: %i[index show create update]
    resources :moves, only: %i[index show create destroy]
    resources :picks, only: %i[index show create]
    resource :a_propos, only: :show, controller: "a_propos"
    # Explorateur et schéma en direct : développement seulement.
    mount VandalUi::Engine, at: "/vandal" if Rails.env.development?
    # your routes go here
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end
