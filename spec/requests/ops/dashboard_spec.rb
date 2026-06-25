# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Ops HTML dashboard", type: :request do
  around do |example|
    prev = ENV["OPS_AUTH_TOKEN"]
    ENV["OPS_AUTH_TOKEN"] = "secret"
    example.run
  ensure
    ENV["OPS_AUTH_TOKEN"] = prev.nil? ? nil.tap { ENV.delete("OPS_AUTH_TOKEN") } : prev
  end

  describe "GET /ops" do
    context "with valid ops token" do
      it "renders HTML dashboard" do
        get "/ops", headers: { "X-Ops-Token" => "secret" }
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("text/html")
        expect(response.body).to include("Ops")
      end

      it "shows queue health metrics" do
        get "/ops", headers: { "X-Ops-Token" => "secret" }
        expect(response.body).to match(/queued|pending|failed/i)
      end
    end

    context "without a token" do
      it "returns 401" do
        get "/ops"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with an invalid token" do
      it "returns 401" do
        get "/ops", headers: { "X-Ops-Token" => "wrong" }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "API endpoints also work with X-Ops-Token" do
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
