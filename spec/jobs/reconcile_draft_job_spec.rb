require "rails_helper"

RSpec.describe ReconcileDraftJob do
  let(:account) { create(:account) }
  let(:imap_connection) { create(:imap_connection, account: account, active: true) }
  let(:booking_request) { create(:booking_request, account: account, status: "reviewing") }
  let(:draft) do
    create(:draft,
      account: account,
      booking_request: booking_request,
      body: "Thank you for your inquiry.",
      original_body: "Thank you for your inquiry.",
      imap_draft_uid: 99,
      status: "pending_review")
  end

  let(:sent_result) do
    Drafts::SentMailReconciler::Result.new(
      outcome: :approved,
      sent_body: "Thank you for your inquiry.",
      similarity: 1.0
    )
  end

  let(:pending_result) do
    Drafts::SentMailReconciler::Result.new(outcome: :pending, sent_body: nil, similarity: nil)
  end

  before { imap_connection }

  describe "#perform" do
    context "when reconciler detects send (approved)" do
      before do
        allow(Drafts::SentMailReconciler).to receive(:call).and_return(sent_result)
      end

      it "creates an outbound Message record" do
        expect {
          described_class.new.perform(draft.id)
        }.to change(Message, :count).by(1)
      end

      it "transitions BookingRequest to confirmed" do
        described_class.new.perform(draft.id)
        expect(booking_request.reload.status).to eq("confirmed")
      end

      it "writes an EventLog entry for the auto-confirm transition" do
        expect {
          described_class.new.perform(draft.id)
        }.to change(EventLog, :count).by(1)
        log = EventLog.last
        expect(log.event_type).to eq("booking_request.status_changed")
        expect(log.payload["from"]).to eq("reviewing")
        expect(log.payload["to"]).to eq("confirmed")
        expect(log.payload["actor"]).to eq("reconcile_draft_job")
      end

      it "sets Message direction to outbound" do
        described_class.new.perform(draft.id)
        expect(Message.last.direction).to eq("outbound")
      end

      it "sets Message body_text from reconciler sent_body" do
        described_class.new.perform(draft.id)
        expect(Message.last.body_text).to eq("Thank you for your inquiry.")
      end
    end

    context "when reconciler detects send (modified)" do
      let(:modified_result) do
        Drafts::SentMailReconciler::Result.new(
          outcome: :modified,
          sent_body: "Thank you for reaching out.",
          similarity: 0.7
        )
      end

      before do
        allow(Drafts::SentMailReconciler).to receive(:call).and_return(modified_result)
      end

      it "creates an outbound Message record" do
        expect {
          described_class.new.perform(draft.id)
        }.to change(Message, :count).by(1)
      end

      it "transitions BookingRequest to confirmed" do
        described_class.new.perform(draft.id)
        expect(booking_request.reload.status).to eq("confirmed")
      end

      it "writes an EventLog entry for the auto-confirm transition" do
        expect {
          described_class.new.perform(draft.id)
        }.to change(EventLog, :count).by(1)
      end
    end

    context "when reconciler returns pending (not sent yet)" do
      before { allow(Drafts::SentMailReconciler).to receive(:call).and_return(pending_result) }

      it "does not create a Message" do
        expect {
          described_class.new.perform(draft.id)
        }.not_to change(Message, :count)
      end

      it "does not change BookingRequest status" do
        described_class.new.perform(draft.id)
        expect(booking_request.reload.status).to eq("reviewing")
      end
    end

    context "when no active IMAP connection exists" do
      before { imap_connection.update!(active: false) }

      it "does not call the reconciler" do
        expect(Drafts::SentMailReconciler).not_to receive(:call)
        described_class.new.perform(draft.id)
      end

      it "does not create a Message" do
        expect {
          described_class.new.perform(draft.id)
        }.not_to change(Message, :count)
      end
    end

    context "when draft is not pending_review" do
      before { draft.update!(status: "approved") }

      it "does not call the reconciler" do
        expect(Drafts::SentMailReconciler).not_to receive(:call)
        described_class.new.perform(draft.id)
      end
    end

    context "when draft has no imap_draft_uid" do
      before { draft.update!(imap_draft_uid: nil) }

      it "does not call the reconciler" do
        expect(Drafts::SentMailReconciler).not_to receive(:call)
        described_class.new.perform(draft.id)
      end
    end
  end
end
