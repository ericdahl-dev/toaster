require "rails_helper"

RSpec.describe AgentMailbox::DemoSeed do
  describe ".call" do
    it "creates a repeatable demo account, inbox message, and booking request" do
      first_run = described_class.call(account_name: "POC Demo Account")
      second_run = described_class.call(account_name: "POC Demo Account")

      expect(first_run.account).to be_persisted
      expect(first_run.account.id).to eq(second_run.account.id)
      expect(first_run.inbox_message.id).to eq(second_run.inbox_message.id)
      expect(first_run.booking_request.id).to eq(second_run.booking_request.id)

      expect(first_run.booking_request.contact.email).to eq("demo.lead@example.com")
      expect(first_run.booking_request.headcount).to eq(120)
      expect(first_run.booking_request.event_date).to eq(Date.new(2026, 6, 14))
      expect(first_run.booking_request.budget_cents).to eq(1_500_000)
      expect(first_run.summary).to include("POC Demo Account")
      expect(first_run.summary).to include("demo-msg-1")
    end
  end
end
