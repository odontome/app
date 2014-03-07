Odontome::Application.routes.draw do

	namespace :api do
    namespace :v1 do
    	post "/authentication" => "authentication#create"
    	resources :datebooks do
        resources :appointments
      end
      resources :balances
      resources :patients
      resources :doctors
		end
	end

  resources :datebooks do
    resources :appointments
  end
  
  resources :patients do
    member do
      get 'appointments'
    end
    resources :notes
  end

  resources :treatments do
    collection do
      get 'predefined_treatments', :as => :predefined_treatments
    end
  end
  
  resources :users
  resources :doctors
  resource :user_session
  resources :password_resets, :only => [ :new, :create, :edit, :update ]
		
  get "/signin" => "user_sessions#new", :as => :signin
  get "/logout" => "user_sessions#destroy", :as => :logout
  get "/signup" => "practices#new", :as => :signup
  get "/practice" => "practices#show", :as => :practice
  post "/practice" => "practices#create"
  get "/practice/settings" => "practices#settings", :as => :practice_settings
  get "/practice/cancel" => "practices#cancel", :as => :practice_cancel
  post "/practice/close" => "practices#close", :as => :practice_close
  post "/practice/:id" => "practices#update", :as => :practice_update
  get "/privacy"  => "welcome#privacy"
  get "/terms"  => "welcome#terms"

  get "/admin/practices" => "admin#practices", :as => :practices_admin

  get '/datebook', to: redirect('/')

  get '/404', :to => 'errors#not_found'
  get '/401', :to => 'errors#unauthorised'
  get '/422', :to => 'errors#server_error'
  get '/500', :to => 'errors#server_error'

  root :to => "welcome#index"

end
