require "net/http"

class GmailOauthService
  class Error < StandardError; end

  AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
  TOKEN_URL = "https://oauth2.googleapis.com/token"
  USERINFO_URL = "https://www.googleapis.com/oauth2/v2/userinfo"

  SCOPES = %w[
    https://mail.google.com/
    https://www.googleapis.com/auth/userinfo.email
  ].freeze

  def initialize(
    client_id: ENV["GMAIL_CLIENT_ID"],
    client_secret: ENV["GMAIL_CLIENT_SECRET"],
    redirect_uri: ENV["GMAIL_REDIRECT_URI"]
  )
    @client_id = client_id
    @client_secret = client_secret
    @redirect_uri = redirect_uri
  end

  def authorization_url(state: nil)
    params = {
      client_id: @client_id,
      redirect_uri: @redirect_uri,
      response_type: "code",
      scope: SCOPES.join(" "),
      access_type: "offline",
      prompt: "consent"
    }
    params[:state] = state if state
    "#{AUTH_URL}?#{URI.encode_www_form(params)}"
  end

  def exchange_code(code)
    response = Net::HTTP.post_form(URI(TOKEN_URL), {
      code: code,
      client_id: @client_id,
      client_secret: @client_secret,
      redirect_uri: @redirect_uri,
      grant_type: "authorization_code"
    })
    parse_response!(response)
  end

  def refresh_access_token(refresh_token)
    response = Net::HTTP.post_form(URI(TOKEN_URL), {
      refresh_token: refresh_token,
      client_id: @client_id,
      client_secret: @client_secret,
      grant_type: "refresh_token"
    })
    parse_response!(response)
  end

  def fetch_user_email(access_token)
    uri = URI(USERINFO_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{access_token}"
    response = http.request(request)
    data = parse_response!(response)
    data["email"]
  end

  private

  def parse_response!(response)
    data = JSON.parse(response.body)
    if data["error"]
      raise GmailOauthService::Error, data["error_description"] || data["error"]
    end
    data
  end
end
