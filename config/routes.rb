Rails.application.routes.draw do
  devise_for :users,
    path: "",
    path_names: {sign_in: "login", sign_out: "logout"},
    controllers: {sessions: "sessions"}

  # Friendly named helpers that mirror the old hand-rolled auth paths
  direct(:login) { new_user_session_path }
  direct(:logout) { destroy_user_session_path }

  get "/up", to: "up#show"

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
    member do
      post :transition
    end
    resources :drafts, only: [] do
      member do
        post :approve
        post :reject
      end
    end
  end
  resources :mail_connections, only: [:index, :new, :create, :edit, :update] do
    resources :inbox_filters, only: [:create, :destroy]
  end
  resources :venues, only: [:index, :new, :create, :edit, :update, :destroy]
  resources :inbox_threads, only: [:index, :show]
end
