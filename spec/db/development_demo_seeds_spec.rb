# frozen_string_literal: true

require "rails_helper"

load Rails.root.join("db/seeds/development_demo.rb")

RSpec.describe DevelopmentDemoSeeds do
  let(:account) { create(:account) }

  describe ".run" do
    it "creates inbox data idempotently" do
      described_class.run(account: account)
      inbox_count = InboxMessage.where(account: account, provider: described_class::PROVIDER).count

      described_class.run(account: account)

      expect(InboxMessage.where(account: account, provider: described_class::PROVIDER).count).to eq(inbox_count)
      expect(inbox_count).to eq(2)
    end

    it "creates venue records" do
      described_class.run(account: account)
      expect(Venue.where(account: account).count).to eq(2)
    end
  end
end
