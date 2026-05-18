# frozen_string_literal: true

require "rails_helper"

RSpec.describe "inbound message timeline broadcast", type: :model do
  let(:account) { create(:account) }
  let(:booking_request) { create(:booking_request, account: account) }
  let(:thread) { booking_request.conversation_thread }

  it "persists message when turbo broadcast fails" do
    allow(Turbo::StreamsChannel).to receive(:broadcast_append_to).and_raise(StandardError, "cable down")

    expect do
      create(
        :message,
        account: account,
        conversation_thread: thread,
        booking_request: booking_request,
        direction: :inbound
      )
    end.to change(Message, :count).by(1)
  end
end
