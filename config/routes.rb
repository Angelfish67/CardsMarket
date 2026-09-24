Rails.application.routes.draw do
  root "dashboards#show"
  namespace :admin do
    root "dashboard#index"
    resources :brainrot_types, except: :show
    resources :packs, except: %i[ show destroy ]
    resources :ranks, only: %i[ index edit update ]
    resources :users, only: %i[ index edit update ]
    resources :market_offers, only: %i[ index destroy ]
    resources :activities, only: :index
  end
  resource :registration, only: %i[ new create ]
  resource :session, only: %i[ new create destroy ]

  get "registrations/new"
  get "packs/index"
  resources :packs, only: [] do
    post :open, on: :member
  end
  resources :pack_openings, only: :show
  resources :brainrot_cards, only: :show do
    resources :rank_pulls, only: :create
    resources :market_offers, only: %i[ new create ]
  end
  resources :market_offers, only: :destroy do
    post :purchase, on: :member
  end
  get "inventory/index"
  get "marketplace/index"
  # Uploads go through the admin form and its validations, not unsigned direct uploads.
  post "/rails/active_storage/direct_uploads", to: ->(_env) { [ 404, { "content-type" => "text/plain" }, [ "Not found" ] ] }
  get "up" => "rails/health#show", as: :rails_health_check
end
