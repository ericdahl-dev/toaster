# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Devise initializer" do
  it "uses the toaster transactional sender address" do
    expect(Devise.mailer_sender).to eq("Toaster <toaster@ericdahl.dev>")
  end
end
