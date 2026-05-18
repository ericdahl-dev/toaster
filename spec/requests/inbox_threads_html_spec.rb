# frozen_string_literal: true

require "rails_helper"

RSpec.describe "InboxThreads HTML", type: :request do
  let(:account) { create(:account) }
  let!(:user) { create(:user, account: account) }
  let!(:thread) { create(:conversation_thread, account: account, subject: "Grand Hall inquiry") }

  before { sign_in user }

  describe "GET /inbox_threads" do
    it "renders the list" do
      get "/inbox_threads"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Inbox Threads")
      expect(response.body).to include("Grand Hall inquiry")
    end

    it "shows archived badge when primary booking request is archived" do
      create(:booking_request, account: account, conversation_thread: thread, archived_at: 1.hour.ago)

      get "/inbox_threads"

      expect(response.body).to include("archived")
    end

    it "does not show other accounts' threads" do
      create(:conversation_thread, subject: "Other thread")
      get "/inbox_threads"

      expect(response.body).not_to include("Other thread")
    end

    it "redirects when signed out" do
      delete "/logout"
      get "/inbox_threads"
      expect(response).to have_http_status(:redirect)
      expect(response.location).to include("/login")
    end
  end

  describe "GET /inbox_threads/:id" do
    it "renders thread detail with messages" do
      msg = create(:inbox_message, account: account, subject: "Grand Hall inquiry",
        from_name: "Jane Doe", body_text: "I want to book your hall.")
      create(:booking_request, account: account,
        conversation_thread: thread, source_inbox_message: msg)

      get "/inbox_threads/#{thread.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Grand Hall inquiry")
      expect(response.body).to include("Jane Doe")
    end

    it "returns 404 for another account's thread" do
      other = create(:conversation_thread)
      get "/inbox_threads/#{other.id}"
      expect(response).to have_http_status(:not_found)
    end
  end
end
