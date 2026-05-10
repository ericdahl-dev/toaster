# frozen_string_literal: true

require "rails_helper"

RSpec.describe "PostHog initializer in test environment" do
  it "is not initialized so no events can be sent" do
    expect(PostHog.initialized?).to be false
  end

  it "raises when capture is called, preventing accidental event sending" do
    expect { PostHog.capture(distinct_id: "test-user", event: "test_event") }
      .to raise_error(RuntimeError, /not initialized/)
  end
end
