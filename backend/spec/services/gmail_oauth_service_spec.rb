require "rails_helper"

RSpec.describe GmailOauthService do
  let(:service) do
    described_class.new(
      client_id: "test_client_id",
      client_secret: "test_client_secret",
      redirect_uri: "http://localhost:3000/gmail/oauth/callback"
    )
  end

  describe "#authorization_url" do
    it "builds a valid Google OAuth URL" do
      url = service.authorization_url(state: "test_state")
      expect(url).to start_with("https://accounts.google.com/o/oauth2/v2/auth")
      expect(url).to include("client_id=test_client_id")
      expect(url).to include("response_type=code")
      expect(url).to include("access_type=offline")
      expect(url).to include("state=test_state")
    end

    it "includes all required OAuth scopes" do
      url = service.authorization_url
      expect(url).to include(URI.encode_www_form_component("https://mail.google.com/"))
    end

    it "omits state parameter when not provided" do
      url = service.authorization_url
      expect(url).not_to include("&state=")
    end
  end

  describe "#exchange_code" do
    let(:token_response) do
      {
        "access_token" => "ya29.access",
        "refresh_token" => "1//refresh",
        "expires_in" => 3600,
        "token_type" => "Bearer"
      }
    end

    it "returns token data on success" do
      fake_response = instance_double(Net::HTTPResponse, body: token_response.to_json)
      allow(Net::HTTP).to receive(:post_form).and_return(fake_response)

      result = service.exchange_code("auth_code")
      expect(result["access_token"]).to eq("ya29.access")
      expect(result["refresh_token"]).to eq("1//refresh")
      expect(result["expires_in"]).to eq(3600)
    end

    it "raises Error when Google returns an error" do
      error_response = { "error" => "invalid_grant", "error_description" => "Token has been expired" }
      fake_response = instance_double(Net::HTTPResponse, body: error_response.to_json)
      allow(Net::HTTP).to receive(:post_form).and_return(fake_response)

      expect { service.exchange_code("bad_code") }.to raise_error(GmailOauthService::Error, "Token has been expired")
    end

    it "raises Error with error code when no description is present" do
      error_response = { "error" => "invalid_client" }
      fake_response = instance_double(Net::HTTPResponse, body: error_response.to_json)
      allow(Net::HTTP).to receive(:post_form).and_return(fake_response)

      expect { service.exchange_code("code") }.to raise_error(GmailOauthService::Error, "invalid_client")
    end
  end

  describe "#refresh_access_token" do
    let(:token_response) do
      {
        "access_token" => "ya29.new_access",
        "expires_in" => 3600,
        "token_type" => "Bearer"
      }
    end

    it "returns a new access token on success" do
      fake_response = instance_double(Net::HTTPResponse, body: token_response.to_json)
      allow(Net::HTTP).to receive(:post_form).and_return(fake_response)

      result = service.refresh_access_token("1//refresh")
      expect(result["access_token"]).to eq("ya29.new_access")
      expect(result["expires_in"]).to eq(3600)
    end

    it "raises Error when refresh fails" do
      error_response = { "error" => "invalid_grant" }
      fake_response = instance_double(Net::HTTPResponse, body: error_response.to_json)
      allow(Net::HTTP).to receive(:post_form).and_return(fake_response)

      expect { service.refresh_access_token("bad_refresh") }.to raise_error(GmailOauthService::Error, "invalid_grant")
    end
  end
end
