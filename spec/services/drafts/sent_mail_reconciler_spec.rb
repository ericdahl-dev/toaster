require "rails_helper"

RSpec.describe Drafts::SentMailReconciler do
  let(:account) { create(:account) }
  let(:imap_connection) { create(:imap_connection, account: account) }
  let(:booking_request) { create(:booking_request, account: account) }
  let(:draft) do
    create(:draft,
      account: account,
      booking_request: booking_request,
      body: "Hello, thank you for your inquiry.",
      original_body: "Hello, thank you for your inquiry.",
      imap_draft_uid: 42,
      status: "pending_review")
  end
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
  end

  describe "single IMAP session" do
    it "opens exactly one TCP connection for the full reconcile" do
      allow(imap_double).to receive(:select)
      allow(imap_double).to receive(:uid_search).and_return([])
      allow(imap_double).to receive(:uid_fetch).and_return([])

      described_class.call(draft: draft, imap_connection: imap_connection)

      expect(Net::IMAP).to have_received(:new).once
    end
  end

  def stub_sent_search(uids)
    allow(imap_double).to receive(:select).with("Sent")
    allow(imap_double).to receive(:uid_search).and_return(uids)
  end

  def stub_sent_message(body)
    mail = Mail.new
    mail.body = body
    raw = mail.to_s

    fetch_result = instance_double(Net::IMAP::FetchData)
    allow(fetch_result).to receive(:attr).and_return({"UID" => 1, "RFC822" => raw})
    allow(imap_double).to receive(:uid_fetch).and_return([fetch_result])
  end

  describe "#call" do
    context "when the sent message is identical to the original body" do
      before do
        stub_sent_search([1])
        stub_sent_message("Hello, thank you for your inquiry.")
      end

      it "marks the draft as approved" do
        result = described_class.call(draft: draft, imap_connection: imap_connection)
        expect(result.outcome).to eq(:approved)
        expect(draft.reload.status).to eq("approved")
      end

      it "records similarity of 1.0" do
        result = described_class.call(draft: draft, imap_connection: imap_connection)
        expect(result.similarity).to eq(1.0)
      end
    end

    context "when the sent message has minor edits (similarity >= 50%)" do
      before do
        stub_sent_search([1])
        stub_sent_message("Hello, thanks for your inquiry.")
      end

      it "marks the draft as modified" do
        result = described_class.call(draft: draft, imap_connection: imap_connection)
        expect(result.outcome).to eq(:modified)
        expect(draft.reload.status).to eq("modified")
      end
    end

    context "when the sent message is heavily rewritten (similarity < 50%)" do
      before do
        stub_sent_search([1])
        stub_sent_message("x" * 200)
      end

      it "marks the draft as rejected" do
        result = described_class.call(draft: draft, imap_connection: imap_connection)
        expect(result.outcome).to eq(:rejected)
        expect(draft.reload.status).to eq("rejected")
      end
    end

    context "when no sent message is found and the IMAP draft still exists" do
      before do
        stub_sent_search([])
        allow(imap_double).to receive(:select).with("Drafts")
        flag_result = instance_double(Net::IMAP::FetchData)
        allow(flag_result).to receive(:attr).and_return({"FLAGS" => [:Draft]})
        allow(imap_double).to receive(:uid_fetch).with([42], "FLAGS").and_return([flag_result])
      end

      it "returns :pending without changing the draft status" do
        result = described_class.call(draft: draft, imap_connection: imap_connection)
        expect(result.outcome).to eq(:pending)
        expect(draft.reload.status).to eq("pending_review")
      end
    end

    context "when no sent message is found and the IMAP draft is gone" do
      before do
        stub_sent_search([])
        allow(imap_double).to receive(:select).with("Drafts")
        allow(imap_double).to receive(:uid_fetch).with([42], "FLAGS").and_return([])
      end

      it "marks the draft as rejected" do
        result = described_class.call(draft: draft, imap_connection: imap_connection)
        expect(result.outcome).to eq(:rejected)
        expect(draft.reload.status).to eq("rejected")
      end
    end
  end

  describe "body_similarity (private — tested via outcomes)" do
    it "treats whitespace-normalised identical bodies as 1.0" do
      draft.update!(original_body: "Hello   world")
      stub_sent_search([1])
      stub_sent_message("Hello world")
      result = described_class.call(draft: draft, imap_connection: imap_connection)
      expect(result.similarity).to eq(1.0)
    end
  end
end
