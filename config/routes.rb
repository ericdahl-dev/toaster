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
    get "/inbox_messages", to: "ops/inbox_messages#index"
    get "/inbox_messages/:id", to: "ops/inbox_messages#show"
    get "/inbox_threads", to: "ops/inbox_threads#index"
    get "/inbox_threads/view", to: "ops/inbox_threads#show"

    resources :ai_runs, only: [:index, :show], controller: "ops/ai_runs"

    post "/retry_failed_job/:id", to: "ops#retry_failed_job"
    post "/retry_draft/:id", to: "ops#retry_draft"
  end

  # GoodJob – Jobs web dashboard (HTML) — admin only
  authenticate :user, ->(u) { u.admin? } do
    mount GoodJob::Engine, at: "/jobs"
  end
  # Non-admin authenticated users hitting /jobs get redirected rather than 404
  get "/jobs", to: redirect("/"), constraints: ->(req) { req.env["warden"]&.authenticated? }

  namespace :admin do
    resources :accounts, only: [:new, :create]
    resources :users, only: [:new, :create]
    resources :waitlist, only: [:index] do
      member do
        get :invite
        post :invite
        post :resend_invite
      end
    end
  end

  root "home#index"

  scope "/onboarding", controller: :onboarding do
    get "/", action: :show, as: :onboarding
    get "/venue", action: :venue, as: :onboarding_venue
    get "/mail_connection", action: :mail_connection, as: :onboarding_mail_connection
    get "/complete", action: :complete, as: :onboarding_complete
    post "/skip", action: :skip, as: :onboarding_skip
  end

  post "/waitlist", to: "waitlist_entries#create", as: :waitlist

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
  resources :venues, only: [:index, :new, :create, :edit, :update, :destroy] do
    resources :documents, only: [:create, :destroy], controller: "venue_documents"
  end
  resources :inbox_threads, only: [:index, :show]
end
