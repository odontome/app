Odontome::Application.routes.draw do
  resources :appointments
  resources :practices
  resources :patients do
    member do
      get 'appointments'
    end
    resources :balances
    resources :notes
    resources :patient_treatments
  end
  resources :treatments
  resources :users
  resources :doctors do
      resources :appointments
  end
  resource :user_session
  resources :password_resets, :only => [ :new, :create, :edit, :update ]

  match "/signin" => "user_sessions#new", :as => :signin
  match "/logout" => "user_sessions#destroy", :as => :logout
  match "/signup" => "practices#new", :as => :signup
  match "/datebook" => "datebook#show", :as => :datebook
  match "/practice" => "practices#show", :as => :practice
  match "/practice/settings" => "practices#settings", :as => :practice_settings
  match "/practice/cancel" => "practices#cancel", :as => :practice_cancel
  match "/practice/change_to_free_plan" => "practices#change_to_free_plan", :as => :change_to_free_plan
  match "/practice/close" => "practices#close", :as => :practice_close, :via => :post
  match "/paypal_ipn" => "paypal#paypal_ipn", :as => :paypal_ipn, :via => :post
  match "/paypal/cancel" => "paypal#cancel"
  match "/paypal/success" => "paypal#success"
  match "/set_session_time_zone"  => "welcome#set_session_time_zone"

  root :to => "welcome#index"

  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  # root :to => "welcome#index"

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id(.:format)))'
end
