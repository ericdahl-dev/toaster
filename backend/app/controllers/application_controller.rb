class ApplicationController < ActionController::API
  include ActionController::Cookies
  include ActionController::RequestForgeryProtection
  include Authentication

  protect_from_forgery with: :null_session
end
