# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Contacts", type: :request do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let!(:contact) { create(:contact, account: account, name: "Alice Smith", email: "alice@example.com") }

  context "when signed in" do
    before { sign_in_as(user) }

    describe "GET /accounts/:account_id/contacts" do
      it "returns all contacts for the account" do
        get "/accounts/#{account.id}/contacts"

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["contacts"].length).to eq(1)
        expect(body["contacts"].first["name"]).to eq("Alice Smith")
      end

      it "filters contacts by query param" do
        create(:contact, account: account, name: "Bob Jones", email: "bob@example.com")
        get "/accounts/#{account.id}/contacts", params: { q: "alice" }

        body = response.parsed_body
        expect(body["contacts"].length).to eq(1)
        expect(body["contacts"].first["name"]).to eq("Alice Smith")
      end

      it "returns 403 for a different account" do
        other = create(:account)
        get "/accounts/#{other.id}/contacts"
        expect(response).to have_http_status(:forbidden)
      end
    end

    describe "GET /accounts/:account_id/contacts/:id" do
      it "returns the contact" do
        get "/accounts/#{account.id}/contacts/#{contact.id}"

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["contact"]["id"]).to eq(contact.id)
      end

      it "returns 404 for an unknown contact" do
        get "/accounts/#{account.id}/contacts/99999"
        expect(response).to have_http_status(:not_found)
      end
    end

    describe "POST /accounts/:account_id/contacts" do
      it "creates a contact" do
        post "/accounts/#{account.id}/contacts",
          params: { contact: { name: "Carol White", email: "carol@example.com", phone: "555-1234" } }

        expect(response).to have_http_status(:created)
        body = response.parsed_body
        expect(body["contact"]["name"]).to eq("Carol White")
        expect(body["contact"]["email"]).to eq("carol@example.com")
      end

      it "returns 422 when name is blank" do
        post "/accounts/#{account.id}/contacts", params: { contact: { name: "" } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["errors"]).to be_present
      end
    end

    describe "PATCH /accounts/:account_id/contacts/:id" do
      it "updates the contact" do
        patch "/accounts/#{account.id}/contacts/#{contact.id}",
          params: { contact: { name: "Alice Updated" } }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["contact"]["name"]).to eq("Alice Updated")
      end

      it "returns 404 for an unknown contact" do
        patch "/accounts/#{account.id}/contacts/99999", params: { contact: { name: "X" } }
        expect(response).to have_http_status(:not_found)
      end
    end

    describe "DELETE /accounts/:account_id/contacts/:id" do
      it "deletes the contact" do
        delete "/accounts/#{account.id}/contacts/#{contact.id}"

        expect(response).to have_http_status(:no_content)
        expect(Contact.find_by(id: contact.id)).to be_nil
      end

      it "returns 422 when contact has open booking requests" do
        thread = create(:conversation_thread, account: account, contact: contact)
        create(:booking_request, account: account, contact: contact, conversation_thread: thread, status: "pending")

        delete "/accounts/#{account.id}/contacts/#{contact.id}"

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["error"]).to match(/open booking request/)
      end

      it "returns 404 for an unknown contact" do
        delete "/accounts/#{account.id}/contacts/99999"
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  context "when signed out" do
    it "returns 401" do
      get "/accounts/#{account.id}/contacts"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
