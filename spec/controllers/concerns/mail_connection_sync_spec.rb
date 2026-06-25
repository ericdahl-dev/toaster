# frozen_string_literal: true

require "rails_helper"

RSpec.describe MailConnectionSync, type: :controller do
  include Devise::Test::ControllerHelpers
  let(:account) { create(:account) }
  let!(:user) { create(:user, account: account) }

  controller(ApplicationController) do
    include MailConnectionSync
    before_action :require_authenticated_user!
    before_action :set_account

    private

    def set_account
      @account = current_user.account
    end

    def connections_scope
      current_user.account.imap_connections
    end

    def connection_id_key
      :imap_connection_id
    end
  end

  before do
    routes.draw do
      post "anonymous/create" => "anonymous#create"
    end
    sign_in user
  end

  describe "POST #create" do
    let!(:conn) { create(:imap_connection, account: account) }

    it "enqueues SyncImapJob and returns 202" do
      expect {
        post :create, params: { connection_id: conn.id }, format: :json
      }.to have_enqueued_job(SyncImapJob).with(conn.id)
      expect(response).to have_http_status(:accepted)
    end

    it "returns the connection id in the response" do
      post :create, params: { connection_id: conn.id }, format: :json
      body = JSON.parse(response.body)
      expect(body["imap_connection_id"]).to eq(conn.id)
      expect(body["status"]).to eq("enqueued")
    end

    it "returns 404 for unknown connection_id" do
      post :create, params: { connection_id: 0 }, format: :json
      expect(response).to have_http_status(:not_found)
    end

    it "does not enqueue a job for another account's connection" do
      other_conn = create(:imap_connection)
      post :create, params: { connection_id: other_conn.id }, format: :json
      expect(response).to have_http_status(:not_found)
    end
  end
end
