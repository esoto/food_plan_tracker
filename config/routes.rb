Rails.application.routes.draw do
  # Single-user OAuth provider used by claude.ai's custom-connector flow.
  # We expose the standard endpoints (authorize/token/revoke) plus a DCR
  # registration endpoint and the two well-known discovery documents.
  use_doorkeeper do
    skip_controllers :applications, :authorized_applications
  end
  post "/oauth/register",                          to: "oauth/registrations#create"
  get  "/.well-known/oauth-authorization-server",  to: "well_known#authorization_server"
  get  "/.well-known/oauth-protected-resource",    to: "well_known#protected_resource"

  match "/mcp", to: "api/mcp#handle", via: %i[get post delete]

  resource :session
  resources :passwords, param: :token

  root "today#show"

  resource :today, only: :show, controller: "today"
  resources :days, only: :show, param: :date, constraints: { date: /\d{4}-\d{2}-\d{2}/ }

  resource :menu, only: :show, controller: "menu"
  resources :exchanges, only: :index
  resources :foods,     only: %i[new create]
  resource :supplements, only: :show, controller: "supplements"
  resource :checklist, only: :show, controller: "checklist"
  resource :progress, only: :show, controller: "progress"
  resource :settings,  only: :show, controller: "settings"
  namespace :settings do
    resources :supplements do
      member { patch :restore }
      collection { get :archived }
    end
    resources :habits, controller: "checklist_templates" do
      member do
        patch :restore
        patch :move_up
        patch :move_down
      end
      collection { get :archived }
    end
  end

  resources :plans, only: :update
  resources :goals, only: :update
  resources :meals, only: :update

  resources :meal_completions,       only: %i[create destroy] do
    collection { post :copy_yesterday }
  end
  resources :supplement_completions, only: %i[create destroy]
  resources :checklist_completions,  only: :update
  resources :biomarker_entries,      only: %i[new create] do
    collection { post :bulk }
  end
  resources :daily_logs,             only: :update
  resources :logged_foods,           only: %i[create update destroy]
  # destroy lives on the collection because the client knows the endpoint
  # URL but not our internal id.
  resource  :notifications, only: :show, controller: "notifications"
  # Single PATCH targeting one preference; identified by composite
  # (reminder_type, key) sent as params, not a URL id.
  patch     "/reminder_preferences", to: "reminder_preferences#update", as: :reminder_preferences

  resources :push_subscriptions, only: :create do
    collection do
      delete :destroy
      post :test
    end
  end

  namespace :api do
    namespace :v1 do
      resource :today, only: :show, controller: "today"

      get "/days/:date", to: "days#show",        constraints: { date: /\d{4}-\d{2}-\d{2}/ }
      patch "/days/:date/plan", to: "days#update_plan", constraints: { date: /\d{4}-\d{2}-\d{2}/ }

      resources :plans, only: :index
      resources :goals, only: :index
      resources :foods, only: %i[index create]
      resources :meals, only: :index

      post   "/weight",                  to: "weight#create"
      post   "/meals/:meal_id/complete", to: "meal_completions#create"
      delete "/meals/:meal_id/complete", to: "meal_completions#destroy"
      post   "/meal_completions/copy_yesterday", to: "meal_completions#copy_yesterday"
      post   "/foods/:food_id/log",      to: "logged_foods#create"
      delete "/logged_foods/:id",        to: "logged_foods#destroy"

      resource :weekly_summary, only: :show, controller: "weekly_summary"

      resources :supplements, only: %i[index create update destroy] do
        member { patch :restore }
      end
      resources :habits, only: %i[index create update destroy] do
        member { patch :restore }
      end
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  # PWA
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
