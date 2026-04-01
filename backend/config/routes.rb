Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  get "/up", to: "up#show"

  # Ops/observability endpoints for operators
  scope "/ops" do
    get "/",               to: "ops#index"
    get "/gmail_connections", to: "ops#gmail_connections"
    get "/webhook_events", to: "ops#webhook_events"
    get "/failed_jobs",    to: "ops#failed_jobs"
    get "/ai_runs",        to: "ops#ai_runs"

    post "/retry_failed_job/:id",    to: "ops#retry_failed_job"
    post "/retry_webhook_event/:id", to: "ops#retry_webhook_event"
    post "/retry_draft/:id",         to: "ops#retry_draft"
  end

  # Mission Control – Jobs web dashboard (HTML)
  mount MissionControl::Jobs::Engine, at: "/jobs"

  # Defines the root path route ("/")
  # root "posts#index"
end
