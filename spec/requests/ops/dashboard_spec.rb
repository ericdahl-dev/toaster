# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Ops HTML dashboard", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) { create(:user, :admin) }
  let(:non_admin) { create(:user) }

  describe "GET /ops" do
    context "as admin" do
      before { sign_in admin }

      it "renders HTML dashboard" do
        get "/ops"
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("text/html")
        expect(response.body).to include("Ops")
      end

      it "shows queue health metrics" do
        get "/ops"
        expect(response.body).to match(/queued|pending|failed/i)
      end
    end

    context "as non-admin user" do
      before { sign_in non_admin }

      it "redirects away" do
        get "/ops"
        expect(response).to have_http_status(:redirect).or have_http_status(:not_found)
      end
    end

    context "unauthenticated" do
      it "redirects to login" do
        get "/ops"
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "API endpoints still work with X-Ops-Token" do
    around do |example|
      prev = ENV["OPS_AUTH_TOKEN"]
      ENV["OPS_AUTH_TOKEN"] = "secret"
      example.run
    ensure
      ENV["OPS_AUTH_TOKEN"] = prev.nil? ? nil.tap { ENV.delete("OPS_AUTH_TOKEN") } : prev
    end

    it "GET /ops/ai_runs returns JSON with token" do
      account = create(:account)
      get "/ops/ai_runs",
        params: { account_id: account.id },
        headers: { "X-Ops-Token" => "secret" }
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("application/json")
    end
  end
end
