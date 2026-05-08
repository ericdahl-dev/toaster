require "rails_helper"

RSpec.describe "GoodJob dashboard", type: :request do
  it "is accessible without authentication" do
    get "/jobs"

    expect(response).to have_http_status(:ok).or have_http_status(:redirect)
  end
end
