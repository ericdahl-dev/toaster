# frozen_string_literal: true

# See lib/middleware/forwarded_host.rb
if Rails.env.development?
  require Rails.root.join("lib/middleware/forwarded_host")
  Rails.application.config.middleware.insert_before 0, Middleware::ForwardedHost
end
