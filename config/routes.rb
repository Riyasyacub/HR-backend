Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      namespace :auth do
        post "sign_in", to: "sessions#create"
        post "refresh", to: "sessions#refresh"
        delete "sign_out", to: "sessions#destroy"
      end

      get "me", to: "me#show"
      resources :employees, only: %i[index create show update] do
        collection { get :team }
        member { get :leave_balances }
      end
      resources :leave_records, only: %i[index show]
      get "assistant/queries", to: "assistant_queries#index"
      post "assistant/queries", to: "assistant_queries#create"
      get "org_chart", to: "org_charts#show"
      get "org_chart/path", to: "org_charts#path"
      get "reports/headcount", to: "reports#headcount"
      get "reports/joiners", to: "reports#joiners"
      get "reports/leave", to: "reports#leave"
      get "reports/payroll", to: "reports#payroll"
      get "reports/trends", to: "reports#trends"
      resources :payroll_runs, only: %i[index create show] do
        member do
          post :recalculate
          post :generate
          post :mark_paid
          get :lines
          get :export
        end
      end
      resources :leave_imports, only: %i[create show] do
        collection { get :template }
      end
      resources :employee_imports, only: %i[create show] do
        collection { get :template }
      end
      namespace :settings do
        resources :countries, only: :index
        resources :leave_types, only: %i[index update]
        resources :departments, only: %i[index create update] do
          member { patch :deactivate }
        end
      end
    end
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
