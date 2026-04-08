require "rails_helper"

RSpec.describe "Ops inbox messages", type: :request do
  around do |example|
    prev = ENV["OPS_AUTH_TOKEN"]
    ENV["OPS_AUTH_TOKEN"] = "secret-token"
    example.run
  ensure
    if prev.nil?
      ENV.delete("OPS_AUTH_TOKEN")
    else
      ENV["OPS_AUTH_TOKEN"] = prev
    end
  end

  describe "GET /ops/inbox_messages" do
    it "returns captured inbox messages with linked booking request summary" do
      account = create(:account)
      inbox_message = create(
        :inbox_message,
        account: account,
        from_name: "Jamie Lead",
        from_email: "jamie@example.com",
        subject: "Wedding inquiry"
      )
      booking_request = create(
        :booking_request,
        account: account,
        source_inbox_message: inbox_message,
        status: "reviewing"
      )

      get "/ops/inbox_messages", headers: { "X-Ops-Token" => "secret-token" }

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      entry = body.fetch("inbox_messages").find { |item| item["id"] == inbox_message.id }
      expect(entry).to include(
        "from_name" => "Jamie Lead",
        "from_email" => "jamie@example.com",
        "subject" => "Wedding inquiry"
      )
      expect(entry.fetch("booking_request")).to include(
        "id" => booking_request.id,
        "status" => "reviewing"
      )
    end

    it "returns 401 when the token header is missing" do
      get "/ops/inbox_messages"

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).to include("error" => "Unauthorized")
    end

    it "returns 401 when the token header is wrong" do
      get "/ops/inbox_messages", headers: { "X-Ops-Token" => "wrong-token" }

      expect(response).to have_http_status(:unauthorized)
    end

    context "when OPS_AUTH_TOKEN is not configured" do
      around do |example|
        saved = ENV.delete("OPS_AUTH_TOKEN")
        example.run
      ensure
        ENV["OPS_AUTH_TOKEN"] = saved if saved
      end

      it "returns 401" do
        get "/ops/inbox_messages", headers: { "X-Ops-Token" => "any-token" }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /ops/inbox_messages/:id" do
    it "returns the inbox message details plus request snapshot" do
      account = create(:account)
      inbox_message = create(
        :inbox_message,
        account: account,
        provider_thread_id: "thread-123",
        provider_message_id: "msg-123",
        from_name: "Jamie Lead",
        from_email: "jamie@example.com",
        subject: "Wedding inquiry",
        body_text: "Looking for June 14, 2026 for 120 guests.",
        raw_payload: { "messageId" => "msg-123", "threadId" => "thread-123" }
      )
      create(
        :booking_request,
        account: account,
        source_inbox_message: inbox_message,
        status: "reviewing",
        headcount: 120,
        event_date: Date.new(2026, 6, 14),
        extraction_snapshot: {
          "event_date" => "2026-06-14",
          "headcount" => 120,
          "budget_cents" => nil
        },
        missing_fields: [ "budget_cents" ],
        review_reasons: []
      )

      get "/ops/inbox_messages/#{inbox_message.id}", headers: { "X-Ops-Token" => "secret-token" }

      expect(response).to have_http_status(:ok)
      detail = response.parsed_body.fetch("inbox_message")
      expect(detail).to include(
        "id" => inbox_message.id,
        "provider_message_id" => "msg-123",
        "provider_thread_id" => "thread-123",
        "from_name" => "Jamie Lead",
        "subject" => "Wedding inquiry",
        "body_text" => "Looking for June 14, 2026 for 120 guests."
      )
      expect(detail.fetch("raw_payload")).to include("messageId" => "msg-123")
      expect(detail.fetch("booking_request")).to include(
        "status" => "reviewing",
        "headcount" => 120,
        "event_date" => "2026-06-14",
        "missing_fields" => [ "budget_cents" ]
      )
    end

    it "returns 404 for an unknown inbox message" do
      get "/ops/inbox_messages/999999", headers: { "X-Ops-Token" => "secret-token" }

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body).to include("error" => "Inbox message not found")
    end

    it "returns 404 when the message exists but is not inbound" do
      account = create(:account)
      outbound_message = create(:inbox_message, account: account, direction: "outbound")

      get "/ops/inbox_messages/#{outbound_message.id}", headers: { "X-Ops-Token" => "secret-token" }

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body).to include("error" => "Inbox message not found")
    end

    it "returns 401 when the token header is missing" do
      account = create(:account)
      inbox_message = create(:inbox_message, account: account)

      get "/ops/inbox_messages/#{inbox_message.id}"

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
