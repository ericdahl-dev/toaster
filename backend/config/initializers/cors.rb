# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    default_origins =
      if Rails.env.development? || Rails.env.test?
        "http://localhost:3000,http://127.0.0.1:3000"
      end

    allowed_origins = ENV["CORS_ORIGINS"].presence || default_origins
    origins(*allowed_origins.to_s.split(",").map(&:strip).reject(&:empty?))

    resource "*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head]
  end
end
