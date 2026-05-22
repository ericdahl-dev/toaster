# frozen_string_literal: true

require "rails_helper"

RSpec.describe Toaster::ResendDeliveryMethod do
  describe "#deliver!" do
    let(:settings) { { api_key: "re_test_123", from: "Toaster <toaster@ericdahl.dev>" } }
    let(:delivery_method) { described_class.new(settings) }
    let(:http) { instance_double(Net::HTTP) }
    let(:mail) do
      Mail.new do
        to "venue@example.com"
        subject "Welcome to Toaster"
        text_part { body "Plain text body" }
        html_part { body "<p>HTML body</p>" }
      end
    end

    before do
      allow(Net::HTTP).to receive(:start).with("api.resend.com", 443, use_ssl: true).and_yield(http)
    end

    it "sends to Resend API with expected payload and headers" do
      response = instance_double(Net::HTTPResponse, code: "200", body: "{\"id\":\"email_123\"}")
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)

      expect(http).to receive(:request) do |request|
        expect(request["Authorization"]).to eq("Bearer re_test_123")
        expect(request["Content-Type"]).to eq("application/json")

        parsed_body = JSON.parse(request.body)
        expect(parsed_body).to eq(
          "from" => "Toaster <toaster@ericdahl.dev>",
          "to" => [ "venue@example.com" ],
          "subject" => "Welcome to Toaster",
          "html" => "<p>HTML body</p>",
          "text" => "Plain text body"
        )

        response
      end

      expect(delivery_method.deliver!(mail)).to eq(response)
    end

    it "raises a delivery error when Resend responds with a non-success status" do
      response = instance_double(Net::HTTPResponse, code: "422", body: "{\"message\":\"invalid\"}")
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
      allow(http).to receive(:request).and_return(response)

      expect { delivery_method.deliver!(mail) }.to raise_error(
        described_class::DeliveryError,
        "Resend delivery failed (422): {\"message\":\"invalid\"}"
      )
    end

    it "raises a delivery error when from is missing in settings" do
      incomplete_delivery_method = described_class.new(api_key: "re_test_123")

      expect { incomplete_delivery_method.deliver!(mail) }.to raise_error(
        described_class::DeliveryError,
        "Resend delivery failed: key not found: :from"
      )
    end

    it "raises a delivery error on network failure" do
      allow(Net::HTTP).to receive(:start).and_raise(Net::OpenTimeout.new("timeout"))

      expect { delivery_method.deliver!(mail) }.to raise_error(
        described_class::DeliveryError,
        "Resend delivery failed: timeout"
      )
    end
  end
end
