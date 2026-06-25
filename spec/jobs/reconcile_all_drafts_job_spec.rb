# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReconcileAllDraftsJob, type: :job do
  describe "#perform" do
    let(:account) { create(:account) }
    let(:imap_connection) { create(:imap_connection, account: account) }

    it "enqueues ReconcileDraftJob for each pending_review draft with an imap_draft_uid" do
      d1 = create(:draft, account: account, status: :pending_review, imap_draft_uid: "uid-1")
      d2 = create(:draft, account: account, status: :pending_review, imap_draft_uid: "uid-2")

      expect { described_class.perform_now }
        .to have_enqueued_job(ReconcileDraftJob).with(d1.id)
        .and have_enqueued_job(ReconcileDraftJob).with(d2.id)
    end

    it "skips pending_review drafts without an imap_draft_uid" do
      create(:draft, account: account, status: :pending_review, imap_draft_uid: nil)

      expect { described_class.perform_now }.not_to have_enqueued_job(ReconcileDraftJob)
    end

    it "skips drafts not in pending_review status" do
      create(:draft, account: account, status: :sent, imap_draft_uid: "uid-1")

      expect { described_class.perform_now }.not_to have_enqueued_job(ReconcileDraftJob)
    end

    it "logs reconcile_drafts_fanout_enqueued with enqueued count" do
      create(:draft, account: account, status: :pending_review, imap_draft_uid: "uid-1")
      create(:draft, account: account, status: :pending_review, imap_draft_uid: "uid-2")

      allow(Rails.logger).to receive(:info).and_call_original
      expect(Rails.logger).to receive(:info).with(/reconcile_drafts_fanout_enqueued/).at_least(:once).and_call_original

      described_class.perform_now
    end
  end
end
