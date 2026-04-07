class UpController < ApplicationController
  def show
    render json: {status: "ok", service: "toaster-backend"}
  end
end
