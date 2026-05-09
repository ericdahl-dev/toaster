# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Mobile layout", type: :request do
  let(:account) { create(:account) }
  let!(:user) { create(:user, account: account) }

  describe "when signed in" do
    before { sign_in user }

    it "renders a hamburger button for mobile nav" do
      get "/booking_requests"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("nav-toggle")
    end

    it "renders a sidebar drawer element" do
      get "/booking_requests"

      expect(response.body).to include("sidebar-drawer")
    end

    it "renders a sidebar overlay element" do
      get "/booking_requests"

      expect(response.body).to include("sidebar-overlay")
    end
  end

  describe "when signed out" do
    it "does not render a hamburger button" do
      get "/"

      expect(response.body).not_to include("nav-toggle")
    end

    it "does not render a sidebar drawer" do
      get "/"

      expect(response.body).not_to include("sidebar-drawer")
    end
  end
end
