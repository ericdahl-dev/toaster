require "rails_helper"

RSpec.describe "Home", type: :request do
  describe "GET /" do
    it "renders the home page with an HTML layout" do
      get "/"

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to match(%r{text/html})
      expect(response.body).to include("Toaster")
    end
  end
end
