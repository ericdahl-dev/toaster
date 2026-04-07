require "rails_helper"

RSpec.describe "Health endpoint", type: :request do
  it "returns JSON status for the app" do
    get "/up"

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq(
      "status" => "ok",
      "service" => "toaster-backend"
    )
  end
end
