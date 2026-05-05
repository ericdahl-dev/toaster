# frozen_string_literal: true

require "rails_helper"

load Rails.root.join("db/seeds/development_demo.rb")

RSpec.describe DevelopmentDemoSeeds do
  let(:account) { create(:account) }

  describe ".run" do
    it "creates inbox and booking data idempotently" do
      described_class.run(account: account)
      inbox_count = InboxMessage.where(account: account, provider: described_class::PROVIDER).count
      booking_count = BookingRequest.where(account: account).count

      described_class.run(account: account)

      expect(InboxMessage.where(account: account, provider: described_class::PROVIDER).count).to eq(inbox_count)
      expect(BookingRequest.where(account: account).count).to eq(booking_count)
      expect(inbox_count).to eq(13)
      expect(booking_count).to eq(9)
    end

    it "covers booking workflow statuses" do
      described_class.run(account: account)
      statuses = BookingRequest.where(account: account).distinct.pluck(:status).sort
      expect(statuses).to eq(%w[cancelled confirmed pending rejected reviewing])
    end
  end
end
