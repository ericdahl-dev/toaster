Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  get "/up", to: "up#show"

  namespace :gmail do
    get "oauth/start", to: "oauth#start"
    get "oauth/callback", to: "oauth#callback"
  end

  resources :accounts, only: [] do
    namespace :gmail do
      resources :connections, only: [ :index, :show ] do
        member do
          post :reconnect
          post :resync
        end
      end
    end

    namespace :agent_mailbox do
      resource :sync, only: :create, controller: :syncs
    end
  end

  # Ops/observability endpoints for operators
  scope "/ops" do
    get "/",               to: "ops#index"
    get "/gmail_connections", to: "ops#gmail_connections"
    get "/webhook_events", to: "ops#webhook_events"
    get "/failed_jobs",    to: "ops#failed_jobs"
    get "/ai_runs",        to: "ops#ai_runs"
    get "/inbox_messages", to: "ops/inbox_messages#index"
    get "/inbox_messages/:id", to: "ops/inbox_messages#show"

    post "/retry_failed_job/:id",    to: "ops#retry_failed_job"
    post "/retry_webhook_event/:id", to: "ops#retry_webhook_event"
    post "/retry_draft/:id",         to: "ops#retry_draft"
  end

  # Mission Control – Jobs web dashboard (HTML)
  mount MissionControl::Jobs::Engine, at: "/jobs"

  # Defines the root path route ("/")
  # root "posts#index"
end
