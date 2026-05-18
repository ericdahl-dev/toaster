# frozen_string_literal: true

require "capybara/cuprite"

Capybara.register_driver(:cuprite) do |app|
  options = {
    window_size: [ 1400, 1400 ],
    browser_options: { "no-sandbox" => nil, "disable-dev-shm-usage" => nil, "headless" => "new" }
  }
  options[:browser_path] = ENV["CHROME_PATH"] if ENV["CHROME_PATH"].present?

  Capybara::Cuprite::Driver.new(app, **options)
end

RSpec.configure do |config|
  # Cuprite needs a local Chrome/Chromium; GHA runners are flaky even with setup-chrome.
  # Run `bundle exec rspec spec/system` locally for js: true smoke tests.
  config.filter_run_excluding js: true if ENV["CI"]

  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  config.before(:each, type: :system, js: true) do
    driven_by :cuprite
  end
end
