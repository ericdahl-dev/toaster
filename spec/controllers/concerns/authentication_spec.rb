# frozen_string_literal: true

require "rails_helper"

RSpec.describe Authentication, type: :controller do
  include Devise::Test::ControllerHelpers
  let(:account) { create(:account) }
  let!(:user) { create(:user, account: account) }

  controller(ApplicationController) do
    include Authentication

    def index
      require_authenticated_user!
      return if performed?
      render json: { ok: true }
    end
  end

  before do
    routes.draw { get "anonymous/index" => "anonymous#index" }
  end

  describe "#require_authenticated_user!" do
    context "when signed in" do
      before { sign_in user }

      it "allows the request through" do
        get :index, format: :json
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq({ "ok" => true })
      end
    end

    context "when not signed in" do
      it "returns 401 JSON" do
        get :index, format: :json
        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)).to eq({ "error" => "Unauthorized" })
      end
    end
  end
end
