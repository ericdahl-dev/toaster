require "rails_helper"

RSpec.describe AgentMailbox::Fetcher do
  around do |example|
    original_api_key = ENV["AGENTMAIL_API_KEY"]
    original_inbox_id = ENV["AGENTMAIL_INBOX_ID"]

    ENV["AGENTMAIL_API_KEY"] = "test-api-key"
    ENV["AGENTMAIL_INBOX_ID"] = "test-inbox@agentmail.to"

    example.run
  ensure
    ENV["AGENTMAIL_API_KEY"] = original_api_key
    ENV["AGENTMAIL_INBOX_ID"] = original_inbox_id
  end

  describe "#fetch_messages" do
    it "fetches and normalizes messages from AgentMail" do
      response_body = {
        count: 1,
        messages: [
          {
            inbox_id: "test-inbox@agentmail.to",
            thread_id: "thread-123",
            message_id: "msg-123",
            labels: ["inbox"],
            timestamp: "2026-04-01T14:00:00Z",
            from: "Lead Person <lead@example.com>",
            to: ["agent@test.com", "Venue Team <venue@example.com>"],
            subject: "Wedding inquiry",
            preview: "Looking for a June date",
            size: 1024,
            updated_at: "2026-04-01T14:00:01Z",
            created_at: "2026-04-01T14:00:00Z"
          }
        ]
      }

      http = instance_double(Net::HTTP)
      request = nil
      response = instance_double(Net::HTTPResponse, body: response_body.to_json)

      allow(Net::HTTP).to receive(:new).with("api.agentmail.to", 443).and_return(http)
      allow(http).to receive(:use_ssl=).with(true)
      allow(http).to receive(:request) do |built_request|
        request = built_request
        response
      end

      messages = described_class.new.fetch_messages

      expect(request.path).to eq("/v0/inboxes/test-inbox@agentmail.to/messages")
      expect(request["Authorization"]).to eq("Bearer test-api-key")

      expect(messages).to eq([
        {
          provider: "agentmail",
          provider_message_id: "msg-123",
          provider_thread_id: "thread-123",
          direction: "inbound",
          from_email: "lead@example.com",
          from_name: "Lead Person",
          to_emails: ["agent@test.com", "venue@example.com"],
          subject: "Wedding inquiry",
          body_text: "Looking for a June date",
          received_at: Time.zone.parse("2026-04-01T14:00:00Z"),
          raw_payload: response_body[:messages].first.deep_stringify_keys
        }
      ])
    end

    it "raises a clear error when the API key is missing" do
      ENV["AGENTMAIL_API_KEY"] = nil

      expect { described_class.new.fetch_messages }
        .to raise_error(AgentMailbox::Fetcher::Error, "AGENTMAIL_API_KEY is not set")
    end

    it "raises a clear error when the inbox id is missing" do
      ENV["AGENTMAIL_INBOX_ID"] = nil

      expect { described_class.new.fetch_messages }
        .to raise_error(AgentMailbox::Fetcher::Error, "AGENTMAIL_INBOX_ID is not set")
    end

    it "raises a clear error when AgentMail returns an API error" do
      http = instance_double(Net::HTTP)
      response = instance_double(
        Net::HTTPResponse,
        body: {name: "not_found", message: "Inbox not found"}.to_json
      )

      allow(Net::HTTP).to receive(:new).with("api.agentmail.to", 443).and_return(http)
      allow(http).to receive(:use_ssl=).with(true)
      allow(http).to receive(:request).and_return(response)

      expect { described_class.new.fetch_messages }
        .to raise_error(AgentMailbox::Fetcher::Error, "Inbox not found")
    end
  end
end
