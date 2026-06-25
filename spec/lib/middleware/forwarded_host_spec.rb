# frozen_string_literal: true

require "rails_helper"

RSpec.describe Middleware::ForwardedHost do
  let(:app) { ->(env) { [ 200, {}, [ env["HTTP_HOST"] ] ] } }
  let(:middleware) { described_class.new(app) }

  def call(env = {})
    middleware.call(Rack::MockRequest.env_for("/", env))
  end

  it "replaces HTTP_HOST with X-Forwarded-Host when present" do
    status, _, body = call("HTTP_X_FORWARDED_HOST" => "localhost:3000")
    expect(body.first).to eq("localhost:3000")
  end

  it "uses the first value when X-Forwarded-Host contains a comma-separated list" do
    status, _, body = call("HTTP_X_FORWARDED_HOST" => "localhost:3000, proxy.internal")
    expect(body.first).to eq("localhost:3000")
  end

  it "strips whitespace from the forwarded host" do
    status, _, body = call("HTTP_X_FORWARDED_HOST" => "  localhost:3000  ")
    expect(body.first).to eq("localhost:3000")
  end

  it "leaves HTTP_HOST unchanged when X-Forwarded-Host is absent" do
    status, _, body = call("HTTP_HOST" => "127.0.0.1:3001")
    expect(body.first).to eq("127.0.0.1:3001")
  end

  it "leaves HTTP_HOST unchanged when X-Forwarded-Host is blank" do
    status, _, body = call("HTTP_X_FORWARDED_HOST" => "", "HTTP_HOST" => "127.0.0.1:3001")
    expect(body.first).to eq("127.0.0.1:3001")
  end

  it "returns the downstream app response status" do
    status, _, _ = call
    expect(status).to eq(200)
  end
end
