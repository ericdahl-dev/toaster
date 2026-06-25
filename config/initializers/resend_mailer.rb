# frozen_string_literal: true

require Rails.root.join("lib/toaster/resend_mailer_config")

Rails.application.config.after_initialize do
  next unless Rails.env.production?

  Toaster::ResendMailerConfig.log_disabled_delivery!
end
