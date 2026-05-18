# frozen_string_literal: true

require "rails_helper"

RSpec.describe Turbo::Streams::AuthorizedChannel, type: :channel do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:booking_request) { create(:booking_request, account: account) }

  before { stub_connection(current_user: user) }

  it "subscribes to booking request streams for the user's account" do
    signed = Turbo::StreamsChannel.signed_stream_name(booking_request)

    subscribe(signed_stream_name: signed)

    expect(subscription).to be_confirmed
  end

  it "rejects streams for another account's booking request" do
    other = create(:booking_request)
    signed = Turbo::StreamsChannel.signed_stream_name(other)

    subscribe(signed_stream_name: signed)

    expect(subscription).to be_rejected
  end
end
