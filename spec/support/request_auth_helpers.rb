# frozen_string_literal: true

module RequestAuthHelpers
  def sign_in_as(user, password: "password123") # rubocop:disable Lint/UnusedMethodArgument
    sign_in user
  end
end

RSpec.configure do |config|
  config.include RequestAuthHelpers, type: :request
end
