# frozen_string_literal: true

require "rails_helper"

RSpec.describe InboxIngestion::SinceOverrideFetcher do
  let(:since) { 7.days.ago }
  let(:messages) { [ double("msg1"), double("msg2") ] }
  let(:fetcher) do
    instance_double(Imap::Fetcher,
      fetch_messages: messages,
      mailbox_peak_uid: 42)
  end

  subject(:override_fetcher) { described_class.new(fetcher, since: since) }

  describe "#fetch_messages" do
    it "delegates to the wrapped fetcher with the since override" do
      expect(fetcher).to receive(:fetch_messages).with(since: since).and_return(messages)
      expect(override_fetcher.fetch_messages).to eq(messages)
    end
  end

  describe "#mailbox_peak_uid" do
    it "delegates to the wrapped fetcher" do
      expect(override_fetcher.mailbox_peak_uid).to eq(42)
    end
  end
end
