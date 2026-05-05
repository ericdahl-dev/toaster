require "rails_helper"

RSpec.describe Drafts::ImapDraftPusher do
  let(:account) { create(:account) }
  let(:imap_connection) { create(:imap_connection, account: account) }
  let(:booking_request) { create(:booking_request, account: account) }
  let(:draft) { create(:draft, account: account, booking_request: booking_request, body: "Hello!") }
  let(:imap_double) { instance_double(Net::IMAP) }

  before do
    allow(Net::IMAP).to receive(:new).and_return(imap_double)
    allow(imap_double).to receive(:login)
    allow(imap_double).to receive(:disconnect)

    folder_result = instance_double(
      Imap::FolderLocator::Result,
      drafts_folder: "Drafts",
      sent_folder: "Sent"
    )
    allow(Imap::FolderLocator).to receive(:call).and_return(folder_result)

    allow(imap_double).to receive(:select)
    allow(imap_double).to receive(:append)
    allow(imap_double).to receive(:uid_search).and_return([99])
  end

  describe "#call" do
    it "appends the message to the Drafts folder" do
      described_class.call(draft: draft, imap_connection: imap_connection)
      expect(imap_double).to have_received(:append).with("Drafts", anything, [:Draft], anything)
    end

    it "persists imap_draft_uid and original_body on the draft" do
      described_class.call(draft: draft, imap_connection: imap_connection)
      draft.reload
      expect(draft.imap_draft_uid).to eq(99)
      expect(draft.original_body).to eq("Hello!")
    end

    it "raises FolderNotFound when Drafts folder cannot be located" do
      folder_result = instance_double(
        Imap::FolderLocator::Result,
        drafts_folder: nil,
        sent_folder: "Sent"
      )
      allow(Imap::FolderLocator).to receive(:call).and_return(folder_result)
      expect {
        described_class.call(draft: draft, imap_connection: imap_connection)
      }.to raise_error(Drafts::ImapDraftPusher::FolderNotFound)
    end
  end
end
