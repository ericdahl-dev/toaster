# frozen_string_literal: true

require "rails_helper"

RSpec.describe "required_env initializer" do
  let(:initializer_path) { Rails.root.join("config/initializers/required_env.rb") }

  def load_initializer(env_overrides = {})
    original_env = ENV.to_h
    env_overrides.each { |k, v| ENV[k] = v }
    load initializer_path
  ensure
    ENV.replace(original_env)
  end

  context "in production" do
    before { allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production")) }

    it "does not raise when all required keys are set" do
      expect {
        load_initializer("OPENAI_API_KEY" => "key1", "UNSTRUCTURED_API_KEY" => "key2")
      }.not_to raise_error
    end

    it "raises when OPENAI_API_KEY is missing" do
      expect {
        load_initializer("OPENAI_API_KEY" => nil, "UNSTRUCTURED_API_KEY" => "key2")
      }.to raise_error(RuntimeError, /OPENAI_API_KEY/)
    end

    it "raises when UNSTRUCTURED_API_KEY is missing" do
      expect {
        load_initializer("OPENAI_API_KEY" => "key1", "UNSTRUCTURED_API_KEY" => nil)
      }.to raise_error(RuntimeError, /UNSTRUCTURED_API_KEY/)
    end
  end

  context "outside production" do
    it "does not raise even when keys are absent" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))
      expect {
        load_initializer("OPENAI_API_KEY" => nil, "UNSTRUCTURED_API_KEY" => nil)
      }.not_to raise_error
    end
  end
end
