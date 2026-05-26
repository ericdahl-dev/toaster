require "rails_helper"

RSpec.describe "Home", type: :request do
  describe "GET /" do
    context "when signed out" do
      it "renders the landing page with a meaningful title" do
        get "/"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("booking inquiries")
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
        expect(response.body).not_to match(/href="[^"]*register/)
      end

      it "renders without the sidebar shell" do
        get "/"

        expect(response.body).not_to include("sidebar")
      end

      it "shows a split hero with a product preview" do
        get "/"

        expect(response.body).to include("lp-hero-grid")
        expect(response.body).to include("lp-hero-preview")
        expect(response.body).to include("thread-bubble--pending")
      end

      it "offers early access via waitlist without a second primary sign-in button" do
        get "/"

        expect(response.body).to include('href="#waitlist"')
        expect(response.body).to include("Request early access")
        expect(response.body).not_to include("Sign in to my account")
      end

      it "labels waitlist fields for accessibility" do
        get "/"

        expect(response.body).to include('for="waitlist_entry_full_name"')
        expect(response.body).to include('for="waitlist_entry_email"')
        expect(response.body).to include("lp-waitlist-label")
      end

      it "explains steps without numbered section labels" do
        get "/"

        expect(response.body).to include("How Toaster works")
        expect(response.body).not_to include(">01<")
        expect(response.body).not_to include(">02<")
        expect(response.body).not_to include(">03<")
        expect(response.body).to include("lp-steps-list")
      end

      it "avoids em-dash punctuation in landing copy" do
        get "/"

        doc = Nokogiri::HTML(response.body)
        landing = doc.at_css(".lp")
        expect(landing).to be_present

        text = landing.text
        expect(text).not_to include("—")
        expect(text).not_to include("–")
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
