require "rails_helper"

RSpec.describe "Ops endpoints", type: :request do
  around do |example|
    prev = ENV["OPS_AUTH_TOKEN"]
    ENV["OPS_AUTH_TOKEN"] = "secret-token"
    example.run
  ensure
    if prev.nil?
      ENV.delete("OPS_AUTH_TOKEN")
    else
      ENV["OPS_AUTH_TOKEN"] = prev
    end
  end

  describe "GET /ops" do
    it "returns a system health summary" do
      create(:draft, status: :pending_review)

      get "/ops", headers: {"X-Ops-Token" => "secret-token"}

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body).to include(
        "queued_jobs",
        "failed_jobs",
        "pending_drafts",
        "approved_drafts"
      )
      expect(body["pending_drafts"]).to be >= 1
    end
  end

  describe "GET /ops/ai_runs" do
    it "returns recent AI runs" do
      run = create(:ai_run)

      get "/ops/ai_runs", headers: {"X-Ops-Token" => "secret-token"}

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      ids = body["ai_runs"].map { |r| r["id"] }
      expect(ids).to include(run.id)
    end

    it "excludes AI runs older than 24 hours" do
      create(:ai_run, created_at: 25.hours.ago)

      get "/ops/ai_runs", headers: {"X-Ops-Token" => "secret-token"}

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["ai_runs"]).to be_empty
    end
  end

  describe "GET /ops/failed_jobs" do
    it "returns an empty list when no jobs have failed" do
      get "/ops/failed_jobs", headers: {"X-Ops-Token" => "secret-token"}

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["failed_jobs"]).to eq([])
    end
  end

  describe "POST /ops/retry_draft/:id" do
    it "enqueues PushDraftJob for an approved draft" do
      draft = create(:draft, status: :approved)

      expect {
        post "/ops/retry_draft/#{draft.id}", headers: {"X-Ops-Token" => "secret-token"}
      }.to have_enqueued_job(PushDraftJob).with(draft.id)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["status"]).to eq("enqueued")
    end

    it "returns 422 when draft is not in approved state" do
      draft = create(:draft, status: :pending_review)

      post "/ops/retry_draft/#{draft.id}", headers: {"X-Ops-Token" => "secret-token"}

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 404 for a missing draft" do
      post "/ops/retry_draft/0", headers: {"X-Ops-Token" => "secret-token"}

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "auth" do
    it "returns 401 when the token header is missing" do
      get "/ops"

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).to include("error" => "Unauthorized")
    end
  end
end
