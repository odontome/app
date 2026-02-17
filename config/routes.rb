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
  delete '/logout' => 'user_sessions#destroy', :as => :logout
  get '/signup' => 'practices#new', :as => :signup

  # practice management
  get '/practice' => 'practices#show', :as => :practice
  post '/practice' => 'practices#create'
  get '/practice/balance' => 'practices#balance', :as => :practice_balance
  get '/practice/appointments' => 'practices#appointments', :as => :practice_appointments
  get '/practice/settings' => 'practices#settings', :as => :practice_settings
  get '/practice/cancel' => 'practices#cancel', :as => :practice_cancel
  post '/practice/close' => 'practices#close', :as => :practice_close
  post '/practice/:id' => 'practices#update', :as => :practice_update

  # static pages
  get '/privacy' => 'welcome#privacy'
  get '/terms' => 'welcome#terms'

  # admin
  get '/admin/practices' => 'admin#practices', :as => :practices_admin
  post '/admin/practices/:id/impersonate' => 'admin#impersonate', as: :admin_practice_impersonate
  delete '/admin/impersonate' => 'admin#stop_impersonating', as: :admin_stop_impersonating

  # audit trail (for practice admins)
  resources :audits, only: %i[index show]

  # unsubscribe links
  get '/patients/:id/unsubscribe' => 'patients#unsubscribe', :as => :patients_unsubscribe
  get '/doctors/:id/unsubscribe' => 'doctors#unsubscribe', :as => :doctors_unsubscribe

  # subscriptions
  resource :subscriptions

  # stripe connect
  resource :connect_account, only: %i[show create] do
    member do
      get :onboarding
      post :refresh_status
    end
  end

  # payments (demo)
  resources :payments, only: %i[index new create] do
    collection do
      get :success
      get :failed
    end
  end

  # Public payment completion using Stripe client_secret (no auth required)
  get '/pay/:client_secret', to: 'payments#pay', as: 'pay_payment'

  namespace :api do
    namespace :webhooks do
      post '/stripe', to: 'stripe#event'
    end
  end

  # announcements
  post '/announcements/dismiss', to: 'announcements#dismiss', as: :dismiss_announcement

  # error handling
  get '/404', to: 'errors#not_found'
  get '/401', to: 'errors#unauthorised'
  get '/422', to: 'errors#server_error'
  get '/500', to: 'errors#server_error'

  root to: 'welcome#index'
end
