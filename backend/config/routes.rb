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
  end
end
