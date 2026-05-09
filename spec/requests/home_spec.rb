require "rails_helper"

RSpec.describe "Home", type: :request do
  describe "GET /" do
    context "when signed out" do
      it "renders the landing page with a meaningful title" do
        get "/"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("AI booking assistant for venues")
      end

      it "includes SEO meta description" do
        get "/"

        expect(response.body).to include('meta name="description"')
      end

      it "renders the hero headline" do
        get "/"

        expect(response.body).to include("Toaster")
      end

      it "has a sign in CTA, not a sign-up link" do
        get "/"

        expect(response.body).to include(login_path)
        expect(response.body).not_to include("sign up")
        expect(response.body).not_to include("register")
      end

      it "renders without the sidebar shell" do
        get "/"

        expect(response.body).not_to include("sidebar")
      end
    end

    context "when signed in" do
      let(:account) { create(:account) }
      let!(:user) { create(:user, account: account) }

      before { sign_in user }

      it "redirects to booking requests" do
        get "/"

        expect(response).to have_http_status(:redirect)
        expect(response.location).to include(booking_requests_path)
      end
    end
  end
end
