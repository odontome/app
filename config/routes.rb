# frozen_string_literal: true

Rails.application.routes.draw do
  resources :datebooks do
    resources :appointments
  end

  resources :patients do
    resources :notes
    resources :balances
  end

  resources :treatments do
    collection do
      get 'predefined_treatments', as: :predefined_treatments
    end
  end

  resources :users
  resources :doctors do
    get '/appointments' => 'doctors#appointments'
  end
  resources :password_resets, only: %i[new create edit update]

  # apps
  resources :reviews

  # authentication
  resource :user_session
  get '/signin' => 'user_sessions#new', :as => :signin
  get '/logout' => 'user_sessions#destroy', :as => :logout
  get '/signup' => 'practices#new', :as => :signup

  # practice management
  get '/practice' => 'practices#show', :as => :practice
  post '/practice' => 'practices#create'
  get '/practice/balance' => 'practices#balance', :as => :practice_balance
  get '/practice/settings' => 'practices#settings', :as => :practice_settings
  get '/practice/cancel' => 'practices#cancel', :as => :practice_cancel
  post '/practice/close' => 'practices#close', :as => :practice_close
  post '/practice/:id' => 'practices#update', :as => :practice_update

  # static pages
  get '/privacy' => 'welcome#privacy'
  get '/terms' => 'welcome#terms'

  # admin
  get '/admin/practices' => 'admin#practices', :as => :practices_admin

  # unsubscribe links
  get '/patients/:id/unsubscribe' => 'patients#unsubscribe', :as => :patients_unsubscribe
  get '/doctors/:id/unsubscribe' => 'doctors#unsubscribe', :as => :doctors_unsubscribe

  # subscriptions
  resource :subscriptions
  namespace :api do
    namespace :webhooks do
      post "/stripe", to: "stripe#event"
    end
  end

  # error handling
  get '/404', to: 'errors#not_found'
  get '/401', to: 'errors#unauthorised'
  get '/422', to: 'errors#server_error'
  get '/500', to: 'errors#server_error'

  root to: 'welcome#index'
end
