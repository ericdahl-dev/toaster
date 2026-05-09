# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Mobile layout", type: :request do
  let(:account) { create(:account) }
  let!(:user) { create(:user, account: account) }

  before { sign_in user }

  describe "application layout" do
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
end
