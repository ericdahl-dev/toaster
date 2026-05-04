Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  get "/up", to: "up#show"

  resources :accounts, only: [] do
    namespace :agent_mailbox do
      resources :connections, only: [:index, :show, :create, :update, :destroy] do
        resource :sync, only: :create, controller: :connection_syncs
      end
      resource :sync, only: :create, controller: :syncs
    end

    namespace :imap do
      resources :connections, only: [:index, :show, :create, :update, :destroy] do
        resource :sync, only: :create, controller: :syncs
      end
    end
  end

  # Ops/observability endpoints for operators
  scope "/ops" do
    get "/", to: "ops#index"
    get "/failed_jobs", to: "ops#failed_jobs"
    get "/ai_runs", to: "ops#ai_runs"
    get "/inbox_messages", to: "ops/inbox_messages#index"
    get "/inbox_messages/:id", to: "ops/inbox_messages#show"

    post "/retry_failed_job/:id", to: "ops#retry_failed_job"
    post "/retry_draft/:id", to: "ops#retry_draft"
  end

  # Mission Control – Jobs web dashboard (HTML)
  mount MissionControl::Jobs::Engine, at: "/jobs"

  # Defines the root path route ("/")
  # root "posts#index"
end
