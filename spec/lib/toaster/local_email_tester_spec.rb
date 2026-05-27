# frozen_string_literal: true

require "rails_helper"

RSpec.describe Toaster::LocalEmailTester do
  let(:account) { create(:account) }
  let!(:imap_connection) { create(:imap_connection, account: account, username: "bookings@venue.test", inbox_folder: "INBOX", active: true) }

  describe "#call" do
    before do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("RESEND_API_KEY").and_return("re_test_123")
      allow_any_instance_of(described_class).to receive(:sleep)
    end

    it "sends via resend and finds message via imap" do
      mailer = instance_double(Toaster::ResendDeliveryMethod, deliver!: true)
      allow(Toaster::ResendDeliveryMethod).to receive(:new).and_return(mailer)

      imap = instance_double(Net::IMAP)
      expect(Imap::Session).to receive(:call).with(imap_connection: imap_connection).and_yield(imap)
      expect(imap).to receive(:select).with("INBOX")
      expect(imap).to receive(:search).with([ "HEADER", "SUBJECT", "Test Subject", "HEADER", "FROM", "customer@example.com" ]).and_return([ 42 ])

      result = described_class.call(
        account_id: account.id,
        from_email: "customer@example.com",
        subject: "Test Subject",
        timeout_seconds: 10,
        poll_interval_seconds: 1
      )

      expect(result.connection).to eq(imap_connection)
      expect(result.subject).to eq("Test Subject")
      expect(result.from_email).to eq("customer@example.com")
      expect(result.matched_uids).to eq([ 42 ])
    end

    it "raises when no IMAP message is found before timeout" do
      allow(Toaster::ResendDeliveryMethod).to receive(:new).and_return(instance_double(Toaster::ResendDeliveryMethod, deliver!: true))
      allow(Process).to receive(:clock_gettime).and_return(0.0, 0.0, 2.0)

      imap = instance_double(Net::IMAP)
      allow(Imap::Session).to receive(:call).and_yield(imap)
      allow(imap).to receive(:select)
      allow(imap).to receive(:search).and_return([])

      expect {
        described_class.call(
          account_id: account.id,
          from_email: "customer@example.com",
          subject: "Missing Subject",
          timeout_seconds: 1,
          poll_interval_seconds: 1
        )
      }.to raise_error(Toaster::LocalEmailTester::Error, /Timed out waiting for IMAP delivery/)
    end
  end
end
