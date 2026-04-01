class GmailWatchService
  class Error < StandardError; end

  WATCH_URL = "https://gmail.googleapis.com/gmail/v1/users/me/watch"
  STOP_URL = "https://gmail.googleapis.com/gmail/v1/users/me/stop"

  def initialize(connection, oauth_service: GmailOauthService.new)
    @connection = connection
    @oauth_service = oauth_service
  end

  def setup(topic_name: default_topic_name)
    ensure_fresh_token!
    data = call_watch_api(topic_name)
    update_connection_watch!(data)
    @connection
  end

  def renew(topic_name: default_topic_name)
    setup(topic_name: topic_name)
  end

  def stop
    ensure_fresh_token!
    call_stop_api
    @connection.update!(
      watch_resource_id: nil,
      watch_history_id: nil,
      watch_expiration: nil
    )
  end

  private

  def ensure_fresh_token!
    return unless @connection.token_expired?

    token_data = @oauth_service.refresh_access_token(@connection.refresh_token)
    @connection.update!(
      access_token: token_data["access_token"],
      token_expires_at: Time.current + token_data["expires_in"].to_i.seconds
    )
  end

  def call_watch_api(topic_name)
    uri = URI(WATCH_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{@connection.access_token}"
    request["Content-Type"] = "application/json"
    request.body = { topicName: topic_name, labelIds: %w[INBOX] }.to_json
    response = http.request(request)
    parse_response!(response)
  end

  def call_stop_api
    uri = URI(STOP_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{@connection.access_token}"
    request["Content-Length"] = "0"
    http.request(request)
  end

  def update_connection_watch!(data)
    @connection.update!(
      watch_history_id: data["historyId"],
      watch_expiration: Time.at(data["expiration"].to_i / 1000)
    )
  end

  def parse_response!(response)
    data = JSON.parse(response.body)
    if data["error"]
      raise GmailWatchService::Error, data.dig("error", "message") || "Gmail watch request failed"
    end
    data
  end

  def default_topic_name
    ENV["GMAIL_PUBSUB_TOPIC"]
  end
end
