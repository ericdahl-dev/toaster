require "rails_helper"

RSpec.describe Imap::FolderLocator do
  let(:account) { create(:account) }
  let(:imap_connection) { create(:imap_connection, account: account) }
  let(:imap_double) { instance_double(Net::IMAP) }

  before do
    allow(Net::IMAP).to receive(:new).and_return(imap_double)
    allow(imap_double).to receive(:login)
    allow(imap_double).to receive(:disconnect)
  end

  def mailbox(name, attrs = [])
    mb = instance_double(Net::IMAP::MailboxList)
    allow(mb).to receive(:name).and_return(name)
    allow(mb).to receive(:attr).and_return(attrs)
    mb
  end

  describe "#call" do
    context "when the server exposes special-use attributes on standard LIST" do
      before do
        drafts_mb = mailbox("Drafts", [:Drafts])
        sent_mb = mailbox("Sent", [:Sent])
        # Both the fallback list and the special-use list return these mailboxes
        allow(imap_double).to receive(:list).and_return([drafts_mb, sent_mb])
      end

      it "picks the folder with the matching special-use attribute" do
        result = described_class.call(imap_connection: imap_connection)
        expect(result.drafts_folder).to eq("Drafts")
        expect(result.sent_folder).to eq("Sent")
      end
    end

    context "when special-use LIST raises and well-known names are present" do
      before do
        drafts_mb = mailbox("Drafts", [])
        sent_mb = mailbox("Sent", [])
        allow(imap_double).to receive(:list).with("", "*").and_return([drafts_mb, sent_mb])
        # The service catches all errors from the special-use attempt; simulate
        # it returning no special-use attributes (empty list) so we fall through
        # to name-based matching — the rescue path is exercised separately by
        # the Net::IMAP version not accepting the keyword argument at all.
      end

      it "falls back to well-known folder names when no special-use attrs present" do
        result = described_class.call(imap_connection: imap_connection)
        expect(result.drafts_folder).to eq("Drafts")
        expect(result.sent_folder).to eq("Sent")
      end
    end

    context "when no recognised folders exist" do
      before do
        allow(imap_double).to receive(:list).and_return([mailbox("INBOX")])
      end

      it "returns nil for both folders" do
        result = described_class.call(imap_connection: imap_connection)
        expect(result.drafts_folder).to be_nil
        expect(result.sent_folder).to be_nil
      end
    end
  end
end
