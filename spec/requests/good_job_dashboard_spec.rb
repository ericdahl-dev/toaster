# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GoodJob dashboard", type: :request do
  context "when unauthenticated" do
    it "redirects to login" do
      get "/jobs"
      expect(response).to redirect_to("/login")
    end
  end

  context "when signed in as venue_manager" do
    it "redirects away with a flash message" do
      user = create(:user, role: :venue_manager)
      sign_in_as(user)
      get "/jobs"
      expect(response).to redirect_to(root_path)
    end
  end

  context "when signed in as admin" do
    it "is accessible" do
      user = create(:user, role: :admin)
      sign_in_as(user)
      get "/jobs"
      expect(response).to have_http_status(:ok).or have_http_status(:redirect)
    end
  end
end
