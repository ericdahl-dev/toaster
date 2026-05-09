# frozen_string_literal: true

module RequestAuthHelpers
  def sign_in_as(user, password: "password123")
    post "/auth/login", params: {email: user.email, password: password}, as: :json
    expect(response).to have_http_status(:ok), -> { "login failed: #{response.body}" }
  end
end

RSpec.configure do |config|
  config.include RequestAuthHelpers, type: :request
end
