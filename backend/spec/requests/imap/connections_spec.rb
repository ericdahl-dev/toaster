# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Imap::Connections", type: :request do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let!(:connection) { create(:imap_connection, account: account) }

  describe "CORS preflight (OPTIONS)" do
    it "allows POST from a configured browser origin" do
      process :options, "/accounts/#{account.id}/imap/connections",
        headers: {
          "HTTP_ORIGIN" => "http://localhost:3000",
          "HTTP_ACCESS_CONTROL_REQUEST_METHOD" => "POST",
          "HTTP_ACCESS_CONTROL_REQUEST_HEADERS" => "content-type"
        }

      expect(response).to have_http_status(:ok)
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("http://localhost:3000")
      expect(response.headers["Access-Control-Allow-Methods"].to_s).to include("POST")
    end
  end

  context "when signed in" do
    before { sign_in_as(user) }

    describe "GET /accounts/:account_id/imap/connections" do
      it "returns all IMAP connections for the account" do
        get "/accounts/#{account.id}/imap/connections"

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["connections"].length).to eq(1)
        expect(body["connections"].first["host"]).to eq(connection.host)
        expect(body["connections"].first["username"]).to eq(connection.username)
      end

      it "does not expose the password" do
        get "/accounts/#{account.id}/imap/connections"

        conn = response.parsed_body["connections"].first
        expect(conn).not_to have_key("password")
      end

      it "returns 401 without a session" do
        post "/auth/logout"
        get "/accounts/#{account.id}/imap/connections"
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns 403 for an account id that is not the signed-in user's account" do
        get "/accounts/99999/imap/connections"
        expect(response).to have_http_status(:forbidden)
      end
    end

    describe "GET /accounts/:account_id/imap/connections/:id" do
      it "returns the connection" do
        get "/accounts/#{account.id}/imap/connections/#{connection.id}"

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["connection"]["id"]).to eq(connection.id)
        expect(body["connection"]["host"]).to eq(connection.host)
      end

      it "returns 404 for an unknown connection" do
        get "/accounts/#{account.id}/imap/connections/99999"
        expect(response).to have_http_status(:not_found)
      end

      it "returns 403 when the connection belongs to a different account" do
        other_account = create(:account)
        get "/accounts/#{other_account.id}/imap/connections/#{connection.id}"
        expect(response).to have_http_status(:forbidden)
      end
    end

    describe "POST /accounts/:account_id/imap/connections" do
      let(:valid_params) do
        {
          imap_connection: {
            host: "imap.fastmail.com",
            port: 993,
            ssl: true,
            username: "booking@venue.example",
            password: "secret123",
            inbox_folder: "INBOX"
          }
        }
      end

      it "creates a new IMAP connection" do
        allow(InboxSyncScheduler).to receive(:schedule)

        post "/accounts/#{account.id}/imap/connections", params: valid_params

        expect(response).to have_http_status(:created)
        body = response.parsed_body
        expect(body["connection"]["host"]).to eq("imap.fastmail.com")
        expect(body["connection"]["username"]).to eq("booking@venue.example")
        expect(body["connection"]).not_to have_key("password")
      end

      it "schedules ingestion after creating a connection" do
        allow(InboxSyncScheduler).to receive(:schedule)

        post "/accounts/#{account.id}/imap/connections", params: valid_params

        new_id = response.parsed_body.dig("connection", "id")
        created = ImapConnection.find(new_id)
        expect(InboxSyncScheduler).to have_received(:schedule).with(created)
      end

      it "returns 422 when required fields are missing" do
        post "/accounts/#{account.id}/imap/connections", params: {imap_connection: {host: ""}}

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["errors"]).to be_present
      end

      it "returns 403 for an account id that is not the signed-in user's account" do
        post "/accounts/99999/imap/connections", params: valid_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    describe "PATCH /accounts/:account_id/imap/connections/:id" do
      it "updates the connection" do
        patch "/accounts/#{account.id}/imap/connections/#{connection.id}",
          params: {imap_connection: {inbox_folder: "Bookings"}}

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["connection"]["inbox_folder"]).to eq("Bookings")
      end

      it "returns 404 for an unknown connection" do
        patch "/accounts/#{account.id}/imap/connections/99999",
          params: {imap_connection: {inbox_folder: "Other"}}
        expect(response).to have_http_status(:not_found)
      end
    end

    describe "DELETE /accounts/:account_id/imap/connections/:id" do
      it "deletes the connection" do
        delete "/accounts/#{account.id}/imap/connections/#{connection.id}"

        expect(response).to have_http_status(:no_content)
        expect(ImapConnection.find_by(id: connection.id)).to be_nil
      end

      it "returns 404 for an unknown connection" do
        delete "/accounts/#{account.id}/imap/connections/99999"
        expect(response).to have_http_status(:not_found)
      end
    end

    describe "POST /accounts/:account_id/imap/connections/:connection_id/sync" do
      it "schedules ingestion and returns accepted" do
        allow(InboxSyncScheduler).to receive(:schedule)

        post "/accounts/#{account.id}/imap/connections/#{connection.id}/sync"

        expect(response).to have_http_status(:accepted)
        body = response.parsed_body
        expect(body["status"]).to eq("enqueued")
        expect(body["imap_connection_id"]).to eq(connection.id)
        expect(InboxSyncScheduler).to have_received(:schedule).with(connection)
      end

      it "returns 404 for an unknown connection" do
        post "/accounts/#{account.id}/imap/connections/99999/sync"
        expect(response).to have_http_status(:not_found)
      end

      it "returns 403 for an account id that is not the signed-in user's account" do
        post "/accounts/99999/imap/connections/#{connection.id}/sync"
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
