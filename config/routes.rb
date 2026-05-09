Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  get "/up", to: "up#show"

  # HTML auth
  get  "/login",  to: "sessions#new"
  post "/login",  to: "sessions#create"
  delete "/logout", to: "sessions#destroy"

  # Ops/observability endpoints for operators
  scope "/ops" do
    get "/", to: "ops#index"
    get "/failed_jobs", to: "ops#failed_jobs"
    get "/ai_runs", to: "ops#ai_runs"
    get "/inbox_messages", to: "ops/inbox_messages#index"
    get "/inbox_messages/:id", to: "ops/inbox_messages#show"
    get "/inbox_threads", to: "ops/inbox_threads#index"
    get "/inbox_threads/view", to: "ops/inbox_threads#show"

    post "/retry_failed_job/:id", to: "ops#retry_failed_job"
    post "/retry_draft/:id", to: "ops#retry_draft"
  end

  # GoodJob – Jobs web dashboard (HTML)
  mount GoodJob::Engine, at: "/jobs"

  root "home#index"

  resources :booking_requests, only: [:index, :show] do
    resources :drafts, only: [] do
      member do
        post :approve
        post :reject
      end
    end
  end
  resources :mail_connections, only: [:index, :new, :create]
end
