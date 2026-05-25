# frozen_string_literal: true

require "rails_helper"

RSpec.describe Toaster::ResendMailerConfig do
  let(:rails_config) do
    ActiveSupport::OrderedOptions.new.tap do |config|
      config.action_mailer = ActiveSupport::OrderedOptions.new
    end
  end

  around do |example|
    original = ENV["RESEND_API_KEY"]
    example.run
  ensure
    if original.nil?
      ENV.delete("RESEND_API_KEY")
    else
      ENV["RESEND_API_KEY"] = original
    end
  end

  describe ".apply!" do
    it "configures Resend delivery when RESEND_API_KEY is set" do
      ENV["RESEND_API_KEY"] = "re_live_123"

      described_class.apply!(rails_config)

      expect(rails_config.action_mailer.delivery_method).to eq(:resend_api)
      expect(rails_config.action_mailer.perform_deliveries).to be(true)
      expect(rails_config.action_mailer.resend_api_settings).to eq(
        api_key: "re_live_123",
        from: "Toaster <toaster@ericdahl.dev>"
      )
    end

    it "disables delivery when RESEND_API_KEY is missing or blank" do
      ENV.delete("RESEND_API_KEY")

      described_class.apply!(rails_config)

      expect(rails_config.action_mailer.delivery_method).to eq(:test)
      expect(rails_config.action_mailer.perform_deliveries).to be(false)
      expect(rails_config.action_mailer.resend_api_settings).to be_nil
    end
  end

  describe ".log_disabled_delivery!" do
    let(:logger) { instance_double(Logger, warn: nil) }

    it "warns when the API key is not configured" do
      ENV.delete("RESEND_API_KEY")

      described_class.log_disabled_delivery!(logger)

      expect(logger).to have_received(:warn).with(
        "RESEND_API_KEY is not set; transactional email delivery is disabled."
      )
    end

    it "does not warn when the API key is configured" do
      ENV["RESEND_API_KEY"] = "re_live_123"

      described_class.log_disabled_delivery!(logger)

      expect(logger).not_to have_received(:warn)
    end
  end
end
