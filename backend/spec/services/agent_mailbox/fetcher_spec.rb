require "rails_helper"

RSpec.describe AgentMailbox::Fetcher do
  let(:connection) { build(:agentmail_connection, inbox_id: "test-inbox@agentmail.to", api_key: "test-api-key") }

  describe "#fetch_messages" do
    let(:response_body) do
      {
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
    end

    it "fetches and normalizes messages from AgentMail" do
      http = instance_double(Net::HTTP)
      built_request = nil
      response = instance_double(Net::HTTPResponse, body: response_body.to_json)

      allow(Net::HTTP).to receive(:new).with("api.agentmail.to", 443).and_return(http)
      allow(http).to receive(:use_ssl=).with(true)
      allow(http).to receive(:request) do |req|
        built_request = req
        response
      end

      messages = described_class.new(connection: connection).fetch_messages

      expect(built_request["Authorization"]).to eq("Bearer test-api-key")
      expect(built_request.path).to start_with("/v0/inboxes/test-inbox@agentmail.to/messages")

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

    it "includes after param when connection has been previously synced" do
      connection.last_synced_at = Time.zone.parse("2026-04-01T10:00:00Z")

      http = instance_double(Net::HTTP)
      built_request = nil
      response = instance_double(Net::HTTPResponse, body: {count: 0, messages: []}.to_json)

      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=).with(true)
      allow(http).to receive(:request) { |req|
        built_request = req
        response
      }

      described_class.new(connection: connection).fetch_messages

      expect(built_request.path).to include("after=")
    end

    it "raises a clear error when AgentMail returns an API error" do
      http = instance_double(Net::HTTP)
      response = instance_double(
        Net::HTTPResponse,
        body: {name: "not_found", message: "Inbox not found"}.to_json
      )

      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=).with(true)
      allow(http).to receive(:request).and_return(response)

      expect { described_class.new(connection: connection).fetch_messages }
        .to raise_error(AgentMailbox::Fetcher::Error, "Inbox not found")
    end
  end
end
