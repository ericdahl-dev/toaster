# frozen_string_literal: true

require "rails_helper"

RSpec.describe SendDraftJob do
  let(:account) { create(:account) }
  let(:imap_connection) { create(:imap_connection, account: account, active: true) }
  let(:booking_request) { create(:booking_request, account: account, status: "reviewing") }
  let(:draft) { create(:draft, account: account, booking_request: booking_request, status: "pending_review") }

  before do
    imap_connection
    allow(Drafts::SmtpSender).to receive(:call)
  end

  describe "#perform" do
    it "calls SmtpSender with draft and imap_connection" do
      expect(Drafts::SmtpSender).to receive(:call).with(draft: draft, imap_connection: imap_connection)
      described_class.new.perform(draft.id)
    end

    context "when no active IMAP connection" do
      before { imap_connection.update!(active: false) }

      it "does not call SmtpSender" do
        expect(Drafts::SmtpSender).not_to receive(:call)
        described_class.new.perform(draft.id)
      end
    end

    context "when draft is not pending_review" do
      before { draft.update!(status: "sent") }

      it "does not call SmtpSender" do
        expect(Drafts::SmtpSender).not_to receive(:call)
        described_class.new.perform(draft.id)
      end
    end

    context "when draft is already sent" do
      before { draft.update!(status: "sent", sent_at: 1.hour.ago) }

      it "does not call SmtpSender" do
        expect(Drafts::SmtpSender).not_to receive(:call)
        described_class.new.perform(draft.id)
      end
    end

    it "creates an outbound Message" do
      expect { described_class.new.perform(draft.id) }.to change(Message, :count).by(1)
    end

    it "sets Message direction to outbound" do
      described_class.new.perform(draft.id)
      expect(Message.last.direction).to eq("outbound")
    end

    it "transitions reviewing BookingRequest to confirmed" do
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
      expect(log.payload["actor"]).to eq("send_draft_job")
    end

    it "does not confirm BookingRequest already in other status" do
      booking_request.update!(status: "pending")
      described_class.new.perform(draft.id)
      expect(booking_request.reload.status).to eq("pending")
    end

    it "captures draft_sent telemetry on success" do
      allow(Telemetry).to receive(:capture)
      described_class.new.perform(draft.id)
      expect(Telemetry).to have_received(:capture).with(
        distinct_id: "account_#{account.id}",
        event: "draft_sent",
        properties: hash_including(draft_id: draft.id, booking_request_id: booking_request.id)
      )
    end

    context "when SmtpSender raises SendError" do
      before do
        allow(Drafts::SmtpSender).to receive(:call)
          .and_raise(Drafts::SmtpSender::SendError, "connection refused")
      end

      it "captures draft_send_failed telemetry" do
        expect(Telemetry).to receive(:capture).with(
          distinct_id: "account_#{account.id}",
          event: "draft_send_failed",
          properties: hash_including(
            draft_id: draft.id,
            error_class: "Drafts::SmtpSender::SendError",
            error_message: "connection refused"
          )
        )
        expect { described_class.new.perform(draft.id) }.to raise_error(Drafts::SmtpSender::SendError)
      end

      it "captures the exception via Telemetry.capture_exception" do
        expect(Telemetry).to receive(:capture_exception).with(
          an_instance_of(Drafts::SmtpSender::SendError),
          "account_#{account.id}"
        )
        expect { described_class.new.perform(draft.id) }.to raise_error(Drafts::SmtpSender::SendError)
      end
    end
  end
end
