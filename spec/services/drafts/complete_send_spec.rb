# frozen_string_literal: true

require "rails_helper"

RSpec.describe Drafts::CompleteSend do
  let(:account) { create(:account) }
  let(:booking_request) { create(:booking_request, account: account, status: "reviewing") }
  let(:draft) do
    create(:draft,
      account: account,
      booking_request: booking_request,
      body: "Thank you for your inquiry.",
      status: "approved")
  end

  def call(sent_body: draft.body, actor: "test")
    described_class.call(draft: draft, sent_body: sent_body, actor: actor)
  end

  describe ".call" do
    it "creates an outbound Message" do
      expect { call }.to change(Message, :count).by(1)
    end

    it "sets Message direction to outbound" do
      call
      expect(Message.last.direction).to eq("outbound")
    end

    it "sets Message body_text from sent_body argument" do
      call(sent_body: "A different sent body")
      expect(Message.last.body_text).to eq("A different sent body")
    end

    it "transitions reviewing BookingRequest to confirmed" do
      call
      expect(booking_request.reload.status).to eq("confirmed")
    end

    it "writes an EventLog entry with the actor" do
      expect { call(actor: "my_job") }.to change(EventLog, :count).by(1)
      log = EventLog.last
      expect(log.event_type).to eq("booking_request.status_changed")
      expect(log.payload["actor"]).to eq("my_job")
    end

    it "does not confirm BookingRequest already in non-reviewing status" do
      booking_request.update!(status: "confirmed")
      call
      expect(booking_request.reload.status).to eq("confirmed")
      expect(EventLog.count).to eq(0)
    end
  end
end
