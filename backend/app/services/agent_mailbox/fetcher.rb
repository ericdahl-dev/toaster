require "net/http"
require "uri"

module AgentMailbox
  class Fetcher
    class Error < StandardError; end

    API_BASE_URL = "https://api.agentmail.to".freeze

    def initialize(connection:)
      @connection = connection
    end

    def fetch_messages
      response = perform_request
      data = JSON.parse(response.body)

      raise Error, data["message"] if data["message"] && data["name"]

      Array(data["messages"]).map { |message| normalize_message(message) }
    end

    private

    attr_reader :connection

    def perform_request
      uri = URI("#{API_BASE_URL}/v0/inboxes/#{connection.inbox_id}/messages")
      params = {limit: 100}
      params[:after] = connection.last_synced_at.iso8601 if connection.last_synced_at
      uri.query = URI.encode_www_form(params)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{connection.api_key}"

      http.request(request)
    end

    def normalize_message(message)
      from_name, from_email = parse_address(message.fetch("from"))

      {
        provider: "agentmail",
        provider_message_id: message.fetch("message_id"),
        provider_thread_id: message.fetch("thread_id"),
        direction: "inbound",
        from_email: from_email,
        from_name: from_name,
        to_emails: Array(message["to"]).filter_map { |address| parse_address(address).last },
        subject: message["subject"],
        body_text: message["preview"],
        received_at: Time.zone.parse(message.fetch("timestamp")),
        raw_payload: message
      }
    end

    def parse_address(value)
      match = value.match(/\A(?:(.+?)\s*<)?([^<>@\s]+@[^<>@\s]+)>?\z/)
      return [nil, value] unless match

      [match[1]&.strip, match[2]]
    end
  end
end
