# frozen_string_literal: true

require "rails_helper"

RSpec.describe PushDraftJob, type: :job do
  let(:account) { create(:account) }
  let(:imap_connection) { create(:imap_connection, account: account, active: true) }
  let(:draft) { create(:draft, account: account, status: "pending_review") }

  before do
    imap_connection
    allow(Drafts::ImapDraftPusher).to receive(:call)
  end

  describe "#perform" do
    it "calls ImapDraftPusher with draft and imap_connection" do
      expect(Drafts::ImapDraftPusher).to receive(:call).with(draft: draft, imap_connection: imap_connection)
      described_class.new.perform(draft.id)
    end

    context "when draft is not pending_review" do
      before { draft.update!(status: "sent") }

      it "does not call ImapDraftPusher" do
        expect(Drafts::ImapDraftPusher).not_to receive(:call)
        described_class.new.perform(draft.id)
      end
    end

    context "when no active IMAP connection exists" do
      before { imap_connection.update!(active: false) }

      it "does not call ImapDraftPusher" do
        expect(Drafts::ImapDraftPusher).not_to receive(:call)
        described_class.new.perform(draft.id)
      end
    end

    context "when ImapDraftPusher raises FolderNotFound" do
      before do
        allow(Drafts::ImapDraftPusher).to receive(:call)
          .and_raise(Drafts::ImapDraftPusher::FolderNotFound, "No Drafts folder")
      end

      it "discards the job (does not re-raise)" do
        expect {
          described_class.perform_now(draft.id)
        }.not_to raise_error
      end
    end

    context "when draft does not exist" do
      it "discards the job (does not re-raise)" do
        expect {
          described_class.perform_now(0)
        }.not_to raise_error
      end
    end

    it "logs a draft_pushed_to_imap event to Rails.logger after a successful push" do
      allow(Drafts::ImapDraftPusher).to receive(:call) do
        draft.update!(imap_draft_uid: 77)
      end

      expect(Rails.logger).to receive(:info).with(include("draft_pushed_to_imap")).at_least(:once)

      described_class.new.perform(draft.id)
    end
  end
end
