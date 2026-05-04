require "rails_helper"

RSpec.describe "Deprecated Gmail routes", type: :request do
  it "does not expose OAuth start" do
    get "/gmail/oauth/start", params: {account_id: 1}
    expect(response).to have_http_status(:not_found)
  end

  it "does not expose OAuth callback" do
    get "/gmail/oauth/callback", params: {code: "x", state: "y"}
    expect(response).to have_http_status(:not_found)
  end

  it "does not expose account Gmail connections index" do
    get "/accounts/1/gmail/connections"
    expect(response).to have_http_status(:not_found)
  end

  it "does not expose account Gmail reconnect" do
    post "/accounts/1/gmail/connections/1/reconnect"
    expect(response).to have_http_status(:not_found)
  end

  it "does not expose account Gmail resync" do
    post "/accounts/1/gmail/connections/1/resync"
    expect(response).to have_http_status(:not_found)
  end
end
