# frozen_string_literal: true

require "rails_helper"

RSpec.describe "pending draft timeline broadcast", type: :model do
  let(:account) { create(:account) }
  let(:booking_request) { create(:booking_request, account: account) }

  it "persists draft when turbo broadcast fails" do
    allow(Turbo::StreamsChannel).to receive(:broadcast_append_to).and_raise(StandardError, "cable down")

    expect do
      create(
        :draft,
        account: account,
        booking_request: booking_request,
        status: :pending_review
      )
    end.to change(Draft, :count).by(1)
  end
end
