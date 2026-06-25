# frozen_string_literal: true

require "rails_helper"

RSpec.describe Drafts::Approve do
  let(:account) { create(:account) }
  let(:booking_request) { create(:booking_request, account: account, status: "reviewing") }
  let(:imap_connection) { create(:imap_connection, account: account) }

  def make_draft(status: "pending_review")
    create(:draft, account: account, booking_request: booking_request, status: status)
  end

  describe ".call" do
    it "transitions draft from pending_review to approved" do
      draft = make_draft
      allow(SendDraftJob).to receive(:perform_later)

      described_class.call(draft: draft)

      expect(draft.reload.status).to eq("approved")
    end

    it "enqueues SendDraftJob after approval" do
      draft = make_draft
      expect(SendDraftJob).to receive(:perform_later).with(draft.id)

      described_class.call(draft: draft)
    end

    it "returns :already_sent when draft is already sent" do
      draft = make_draft(status: "sent")

      result = described_class.call(draft: draft)

      expect(result).to eq(:already_sent)
    end

    it "does not enqueue job when draft is already sent" do
      draft = make_draft(status: "sent")
      expect(SendDraftJob).not_to receive(:perform_later)

      described_class.call(draft: draft)
    end

    it "returns :not_pending when draft is not awaiting approval" do
      draft = make_draft(status: "rejected")

      result = described_class.call(draft: draft)

      expect(result).to eq(:not_pending)
    end

    it "does not enqueue job when draft is not pending_review" do
      draft = make_draft(status: "rejected")
      expect(SendDraftJob).not_to receive(:perform_later)

      described_class.call(draft: draft)
    end

    it "returns :ok on success" do
      draft = make_draft
      allow(SendDraftJob).to receive(:perform_later)

      result = described_class.call(draft: draft)

      expect(result).to eq(:ok)
    end

    it "is idempotent: already-approved draft returns :not_pending and does not enqueue" do
      draft = make_draft(status: "approved")
      expect(SendDraftJob).not_to receive(:perform_later)

      result = described_class.call(draft: draft)

      expect(result).to eq(:not_pending)
    end

    it "captures draft_queued telemetry when approval succeeds" do
      draft = make_draft
      allow(SendDraftJob).to receive(:perform_later)

      expect(Telemetry).to receive(:capture).with(
        distinct_id: "account_#{account.id}",
        event: "draft_queued",
        properties: { draft_id: draft.id, booking_request_id: booking_request.id }
      )

      described_class.call(draft: draft)
    end

    it "does not capture draft_queued telemetry when draft is already sent" do
      draft = make_draft(status: "sent")

      expect(Telemetry).not_to receive(:capture)

      described_class.call(draft: draft)
    end

    it "does not capture draft_queued telemetry when draft is not pending" do
      draft = make_draft(status: "rejected")

      expect(Telemetry).not_to receive(:capture)

      described_class.call(draft: draft)
    end
  end
end
