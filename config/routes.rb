Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  root "today#show"

  resource :today, only: :show, controller: "today"
  resources :days, only: :show, param: :date, constraints: { date: /\d{4}-\d{2}-\d{2}/ }

  resource :menu, only: :show, controller: "menu"
  resources :exchanges, only: :index
  resource :supplements, only: :show, controller: "supplements"
  resource :checklist, only: :show, controller: "checklist"
  resource :progress, only: :show, controller: "progress"
  resource :settings,  only: :show, controller: "settings"

  resources :plans, only: :update
  resources :goals, only: :update

  resources :meal_completions,       only: %i[create destroy]
  resources :supplement_completions, only: %i[create destroy]
  resources :checklist_completions,  only: :update
  resources :biomarker_entries,      only: %i[create]
  resources :daily_logs,             only: :update
  resources :logged_foods,           only: %i[create destroy]

  namespace :api do
    namespace :v1 do
      resource :today, only: :show, controller: "today"

      get  "/days/:date", to: "days#show",        constraints: { date: /\d{4}-\d{2}-\d{2}/ }
      patch "/days/:date/plan", to: "days#update_plan", constraints: { date: /\d{4}-\d{2}-\d{2}/ }

      resources :plans, only: :index
      resources :goals, only: :index
      resources :foods, only: :index
      resources :meals, only: :index

      post   "/weight",                  to: "weight#create"
      post   "/meals/:meal_id/complete", to: "meal_completions#create"
      delete "/meals/:meal_id/complete", to: "meal_completions#destroy"
      post   "/foods/:food_id/log",      to: "logged_foods#create"
      delete "/logged_foods/:id",        to: "logged_foods#destroy"
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  # PWA
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
