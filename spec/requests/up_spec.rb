require "rails_helper"

RSpec.describe "Health endpoint", type: :request do
  it "returns 200 with ok status and passing checks" do
    get "/up"

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body["status"]).to eq("ok")
    expect(body["service"]).to eq("toaster-backend")
    expect(body.dig("checks", "database", "ok")).to be true
  end

  it "returns 503 when database is unavailable" do
    allow(ActiveRecord::Base.connection).to receive(:execute).and_raise(PG::ConnectionBad, "connection refused")

    get "/up"

    expect(response).to have_http_status(:service_unavailable)
    body = response.parsed_body
    expect(body["status"]).to eq("degraded")
    expect(body.dig("checks", "database", "ok")).to be false
    expect(body.dig("checks", "database", "error")).to be_present
  end
end
