require "rails_helper"

RSpec.describe InboxIngestion::ImapAdapter do
  describe "#mark_seen" do
    let(:account) { create(:account) }
    let(:imap_connection) { create(:imap_connection, account: account) }
    let(:imap_double) { instance_double(Net::IMAP) }

    before do
      allow(Net::IMAP).to receive(:new).and_return(imap_double)
      allow(imap_double).to receive(:login)
      allow(imap_double).to receive(:select)
      allow(imap_double).to receive(:disconnect)
    end

    it "calls uid_store with +FLAGS \\Seen for the given UIDs" do
      allow(imap_double).to receive(:uid_store)

      described_class.new(imap_connection: imap_connection).mark_seen([ 42, 99 ])

      expect(imap_double).to have_received(:uid_store).with([ 42, 99 ], "+FLAGS", [ :Seen ])
    end

    it "does nothing when given an empty array" do
      described_class.new(imap_connection: imap_connection).mark_seen([])

      expect(imap_double).not_to have_received(:select)
    end
  end
end
