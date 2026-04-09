require "rails_helper"

RSpec.describe "Mission Control Jobs", type: :request do
  around do |example|
    prev_enabled = MissionControl::Jobs.http_basic_auth_enabled
    prev_user = MissionControl::Jobs.http_basic_auth_user
    prev_password = MissionControl::Jobs.http_basic_auth_password

    MissionControl::Jobs.http_basic_auth_enabled = true
    MissionControl::Jobs.http_basic_auth_user = "ops"
    MissionControl::Jobs.http_basic_auth_password = "secret-password"

    example.run
  ensure
    MissionControl::Jobs.http_basic_auth_enabled = prev_enabled
    MissionControl::Jobs.http_basic_auth_user = prev_user
    MissionControl::Jobs.http_basic_auth_password = prev_password
  end

  it "requires authentication" do
    get "/jobs"

    expect(response).to have_http_status(:unauthorized)
  end

  it "does not treat wrong credentials as authorized" do
    credentials = ActionController::HttpAuthentication::Basic.encode_credentials("ops", "wrong-password")

    get "/jobs", headers: {"HTTP_AUTHORIZATION" => credentials}

    expect(response).to have_http_status(:unauthorized)
  end
end
