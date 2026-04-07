require "rails_helper"

RSpec.describe "Ops endpoints", type: :request do
  describe "GET /ops" do
    it "returns a system health summary" do
      create(:gmail_connection, active: true)
      create(:draft, status: :pending_review)
      create(:gmail_webhook_event)  # unprocessed by default

      get "/ops"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body).to include(
        "queued_jobs",
        "failed_jobs",
        "unprocessed_webhook_events",
        "active_gmail_connections",
        "pending_drafts",
        "approved_drafts"
      )
      expect(body["active_gmail_connections"]).to be >= 1
      expect(body["pending_drafts"]).to be >= 1
      expect(body["unprocessed_webhook_events"]).to be >= 1
    end
  end

  describe "GET /ops/gmail_connections" do
    it "returns all gmail connections" do
      conn = create(:gmail_connection, active: true)

      get "/ops/gmail_connections"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["gmail_connections"]).to be_an(Array)
      entry = body["gmail_connections"].find { |c| c["id"] == conn.id }
      expect(entry).to include("email" => conn.email, "active" => true)
    end
  end

  describe "GET /ops/webhook_events" do
    it "returns webhook events with processed status" do
      unprocessed = create(:gmail_webhook_event)
      processed = create(:gmail_webhook_event, processed_at: 1.hour.ago)

      get "/ops/webhook_events"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      ids = body["webhook_events"].map { |e| e["id"] }
      expect(ids).to include(unprocessed.id, processed.id)
    end
  end

  describe "GET /ops/ai_runs" do
    it "returns recent AI runs" do
      run = create(:ai_run)

      get "/ops/ai_runs"

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      ids = body["ai_runs"].map { |r| r["id"] }
      expect(ids).to include(run.id)
    end

    it "excludes AI runs older than 24 hours" do
      create(:ai_run, created_at: 25.hours.ago)

      get "/ops/ai_runs"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["ai_runs"]).to be_empty
    end
  end

  describe "GET /ops/failed_jobs" do
    it "returns an empty list when no jobs have failed" do
      get "/ops/failed_jobs"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["failed_jobs"]).to eq([])
    end
  end

  describe "POST /ops/retry_webhook_event/:id" do
    it "re-enqueues an unprocessed webhook event" do
      event = create(:gmail_webhook_event)

      expect {
        post "/ops/retry_webhook_event/#{event.id}"
      }.to have_enqueued_job(ProcessGmailWebhookEventJob).with(event.id)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["status"]).to eq("enqueued")
    end

    it "re-queues a previously processed webhook event" do
      event = create(:gmail_webhook_event, processed_at: 1.hour.ago)

      post "/ops/retry_webhook_event/#{event.id}"

      expect(response).to have_http_status(:ok)
      expect(event.reload.processed_at).to be_nil
    end

    it "returns 404 for a missing webhook event" do
      post "/ops/retry_webhook_event/0"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /ops/retry_draft/:id" do
    it "enqueues SendDraftJob for an approved draft" do
      draft = create(:draft, status: :approved)

      expect {
        post "/ops/retry_draft/#{draft.id}"
      }.to have_enqueued_job(SendDraftJob).with(draft.id)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["status"]).to eq("enqueued")
    end

    it "returns 422 when draft is not in approved state" do
      draft = create(:draft, status: :pending_review)

      post "/ops/retry_draft/#{draft.id}"

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 404 for a missing draft" do
      post "/ops/retry_draft/0"

      expect(response).to have_http_status(:not_found)
    end
  end
end
