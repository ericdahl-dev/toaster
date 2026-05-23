# frozen_string_literal: true

module Toaster
  module ResendMailerConfig
    DEFAULT_FROM = "Toaster <toaster@ericdahl.dev>"
    MISSING_KEY_MESSAGE = "RESEND_API_KEY is not set; transactional email delivery is disabled."

    class << self
      def api_key
        ENV["RESEND_API_KEY"].presence
      end

      def enabled?
        api_key.present?
      end

      def apply!(config)
        if enabled?
          config.action_mailer.delivery_method = :resend_api
          config.action_mailer.resend_api_settings = {
            api_key: api_key,
            from: DEFAULT_FROM
          }
          config.action_mailer.perform_deliveries = true
        else
          config.action_mailer.delivery_method = :test
          config.action_mailer.perform_deliveries = false
        end
      end

      def log_disabled_delivery!(logger = Rails.logger)
        return if enabled?

        logger.warn(MISSING_KEY_MESSAGE)
      end
    end
  end
end
