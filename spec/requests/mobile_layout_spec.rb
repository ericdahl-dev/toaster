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

    it "does not show the Admin section for a non-admin user" do
      get "/booking_requests"

      expect(response.body).not_to include("admin_waitlist")
      expect(response.body).not_to include("Prospects")
    end
  end

  describe "when signed in as admin" do
    let!(:admin) { create(:user, :admin, account: account) }

    before { sign_in admin }

    it "shows the Admin section with a Prospects link" do
      get "/booking_requests"

      expect(response.body).to include("Prospects")
      expect(response.body).to include("/admin/waitlist")
    end

    it "links the deployed chip to the pull request when the revision includes one" do
      stub_const("APP_REVISION", "abc1234 feat: shipped change (#99)")

      get "/booking_requests"

      expect(response.body).to include("Deployed")
      expect(response.body).to include("https://github.com/ericdahl-dev/toaster/pull/99")
      expect(response.body).to include("abc1234")
    end

    it "shows the deployed sha without a pull request link when the revision has no pr number" do
      stub_const("APP_REVISION", "abc1234")

      get "/booking_requests"

      expect(response.body).to include("Deployed")
      expect(response.body).to include("abc1234")
      expect(response.body).not_to include("https://github.com/ericdahl-dev/toaster/pull/")
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
