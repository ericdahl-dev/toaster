# frozen_string_literal: true

require "rails_helper"

RSpec.describe "MailConnections HTML", type: :request do
  let(:account) { create(:account) }
  let!(:user) { create(:user, account: account) }

  describe "GET /mail_connections" do
    context "when signed in" do
      before { sign_in user }

      it "renders the list" do
        create(:imap_connection, account: account)

        get "/mail_connections"

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to match(%r{text/html})
        expect(response.body).to include("Mail Connections")
      end

      it "does not show other accounts' connections" do
        other = create(:imap_connection)
        get "/mail_connections"

        expect(response.body).not_to include(other.username)
      end
    end

    context "when signed out" do
      it "redirects to login" do
        get "/mail_connections"
        expect(response).to have_http_status(:redirect)
        expect(response.location).to include("/login")
      end
    end
  end

  describe "GET /mail_connections/new" do
    context "when signed in" do
      before { sign_in user }

      it "renders the new form" do
        get "/mail_connections/new"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Add Mail Connection")
      end
    end

    context "when signed out" do
      it "redirects to login" do
        get "/mail_connections/new"
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe "POST /mail_connections" do
    context "when signed in" do
      before { sign_in user }

      it "creates an IMAP connection and redirects" do
        post "/mail_connections", params: {
          mail_connection: {
            type: "imap",
            host: "imap.example.com",
            port: "993",
            username: "user@example.com",
            password: "secret",
            inbox_folder: "INBOX"
          }
        }

        expect(response).to have_http_status(:redirect)
        expect(ImapConnection.where(account: account, host: "imap.example.com")).to exist
      end

      it "re-renders with errors on invalid params" do
        post "/mail_connections", params: {
          mail_connection: {type: "imap", host: "", port: "", username: "", password: ""}
        }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Add Mail Connection")
      end
    end
  end

  describe "PATCH /mail_connections/:id (SMTP fields)" do
    let!(:imap_connection) { create(:imap_connection, account: account) }

    context "when signed in" do
      before { sign_in user }

      it "saves smtp_host and smtp_port" do
        patch "/mail_connections/#{imap_connection.id}", params: {
          mail_connection: {smtp_host: "smtp.custom.com", smtp_port: "465"}
        }

        expect(response).to have_http_status(:redirect)
        imap_connection.reload
        expect(imap_connection.smtp_host).to eq("smtp.custom.com")
        expect(imap_connection.smtp_port).to eq(465)
      end

      it "renders smtp fields in edit form" do
        get "/mail_connections/#{imap_connection.id}/edit"
        expect(response.body).to include("smtp_host")
        expect(response.body).to include("smtp_port")
      end
    end
  end
end
