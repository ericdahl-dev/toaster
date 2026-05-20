# frozen_string_literal: true

require "rails_helper"

RSpec.describe Drafts::Reject do
  let(:account) { create(:account) }
  let(:booking_request) { create(:booking_request, account: account, status: "reviewing") }

  def make_draft(status: "pending_review")
    create(:draft, account: account, booking_request: booking_request, status: status)
  end

  describe ".call" do
    it "transitions draft to rejected" do
      draft = make_draft

      described_class.call(draft: draft)

      expect(draft.reload.status).to eq("rejected")
    end

    it "returns :ok" do
      draft = make_draft

      result = described_class.call(draft: draft)

      expect(result).to eq(:ok)
    end

    it "can reject an already-rejected draft (idempotent status write)" do
      draft = make_draft(status: "rejected")

      result = described_class.call(draft: draft)

      expect(result).to eq(:ok)
      expect(draft.reload.status).to eq("rejected")
    end
  end
end
