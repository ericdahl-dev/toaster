# frozen_string_literal: true

require "rails_helper"

RSpec.describe MailConnections, type: :controller do
  include Devise::Test::ControllerHelpers

  let(:account) { create(:account) }
  let!(:user) { create(:user, account: account) }

  controller(ApplicationController) do
    include MailConnections
    before_action :require_authenticated_user!

    private

    def connections_scope
      current_user.account.imap_connections
    end

    def connection_params
      params.require(:connection).permit(:host, :port, :username, :password, :inbox_folder, :ssl)
    end

    def connection_json(c)
      { id: c.id, host: c.host, username: c.username }
    end
  end

  before do
    routes.draw do
      get    "anonymous/index"   => "anonymous#index"
      get    "anonymous/show"    => "anonymous#show"
      post   "anonymous/create"  => "anonymous#create"
      patch  "anonymous/update"  => "anonymous#update"
      delete "anonymous/destroy" => "anonymous#destroy"
    end
    sign_in user
  end

  describe "GET #index" do
    it "returns all connections as JSON" do
      conn = create(:imap_connection, account: account, host: "imap.example.com")
      get :index, format: :json
      body = JSON.parse(response.body)
      expect(body["connections"].map { |c| c["id"] }).to include(conn.id)
    end

    it "does not include other accounts' connections" do
      other = create(:imap_connection)
      get :index, format: :json
      body = JSON.parse(response.body)
      expect(body["connections"].map { |c| c["id"] }).not_to include(other.id)
    end
  end

  describe "GET #show" do
    let(:conn) { create(:imap_connection, account: account) }

    it "returns the connection JSON" do
      get :show, params: { id: conn.id }, format: :json
      body = JSON.parse(response.body)
      expect(body["connection"]["id"]).to eq(conn.id)
    end

    it "returns 404 for unknown id" do
      get :show, params: { id: 0 }, format: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST #create" do
    let(:valid_params) do
      { connection: { host: "imap.new.com", port: 993, username: "u@new.com",
                      password: "secret", inbox_folder: "INBOX", ssl: true } }
    end

    it "creates a connection and returns 201" do
      expect {
        post :create, params: valid_params, format: :json
      }.to change(ImapConnection, :count).by(1)
      expect(response).to have_http_status(:created)
    end

    it "enqueues SyncImapJob for the new connection" do
      expect {
        post :create, params: valid_params, format: :json
      }.to have_enqueued_job(SyncImapJob)
    end

    it "returns errors on invalid params" do
      post :create, params: { connection: { host: "" } }, format: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)).to have_key("errors")
    end
  end

  describe "PATCH #update" do
    let(:conn) { create(:imap_connection, account: account, host: "imap.old.com") }

    it "updates the connection" do
      patch :update, params: { id: conn.id, connection: { host: "imap.updated.com" } }, format: :json
      expect(response).to have_http_status(:ok)
      expect(conn.reload.host).to eq("imap.updated.com")
    end

    it "returns errors on invalid update" do
      patch :update, params: { id: conn.id, connection: { host: "" } }, format: :json
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "DELETE #destroy" do
    let!(:conn) { create(:imap_connection, account: account) }

    it "destroys the connection and returns 204" do
      expect {
        delete :destroy, params: { id: conn.id }, format: :json
      }.to change(ImapConnection, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end
  end
end
