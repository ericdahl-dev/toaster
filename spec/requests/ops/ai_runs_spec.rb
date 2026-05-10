# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Ops::AiRuns", type: :request do
  around do |example|
    prev = ENV["OPS_AUTH_TOKEN"]
    ENV["OPS_AUTH_TOKEN"] = "secret-token"
    example.run
  ensure
    ENV["OPS_AUTH_TOKEN"] = prev.nil? ? nil.tap { ENV.delete("OPS_AUTH_TOKEN") } : prev
  end

  let(:headers) { {"X-Ops-Token" => "secret-token"} }
  let(:account) { create(:account) }
  let(:booking_request) { create(:booking_request, account:) }

  describe "GET /ops/ai_runs" do
    it "lists AI runs" do
      run = create(:ai_run, account:, booking_request:, run_type: "extraction")
      get "/ops/ai_runs", headers: headers
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["ai_runs"].map { |r| r["id"] }).to include(run.id)
    end

    it "filters by run_type" do
      create(:ai_run, account:, booking_request:, run_type: "extraction")
      classifier_run = create(:ai_run, account:, run_type: "classifier")
      get "/ops/ai_runs", params: {run_type: "classifier"}, headers: headers
      ids = response.parsed_body["ai_runs"].map { |r| r["id"] }
      expect(ids).to include(classifier_run.id)
      expect(ids.size).to eq(1)
    end
  end

  describe "GET /ops/ai_runs/:id" do
    it "returns full prompt, response, model, version and latency" do
      run = create(:ai_run, account:, booking_request:, run_type: "extraction",
        prompt: "Subject: test\n\nBody: hello",
        response: '{"event_date":null}',
        llm_model: "gpt-4o-mini",
        prompt_version: "extractor-v1",
        latency_ms: 423)

      get "/ops/ai_runs/#{run.id}", headers: headers

      expect(response).to have_http_status(:ok)
      body = response.parsed_body["ai_run"]
      expect(body["prompt"]).to eq("Subject: test\n\nBody: hello")
      expect(body["response"]).to eq('{"event_date":null}')
      expect(body["llm_model"]).to eq("gpt-4o-mini")
      expect(body["prompt_version"]).to eq("extractor-v1")
      expect(body["latency_ms"]).to eq(423)
      expect(body["rag_chunk_count"]).to eq(0)
    end

    it "returns 404 for unknown id" do
      get "/ops/ai_runs/0", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end
end

RSpec.describe "BookingRequests HTML", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:booking_request) { create(:booking_request, account:, staff_summary: "Great lead, 40 guests, June 14.") }

  before { sign_in user }

  describe "GET /booking_requests/:id" do
    it "shows staff_summary when present" do
      get booking_request_path(booking_request)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Great lead, 40 guests, June 14.")
    end

    it "links to ai_runs for the booking_request" do
      run = create(:ai_run, account:, booking_request:, run_type: "extraction")
      get booking_request_path(booking_request)
      expect(response.body).to include("/ops/ai_runs/#{run.id}")
    end
  end
end
