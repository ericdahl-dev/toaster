# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationCable::Connection, type: :channel do
  it "rejects unauthenticated connections" do
    expect { connect }.to have_rejected_connection
  end

  it "identifies the signed-in user" do
    user = create(:user)
    warden = instance_double(Warden::Proxy)
    allow(warden).to receive(:user).with(:user).and_return(user)

    connect env: { "warden" => warden }

    expect(connection.current_user).to eq(user)
  end
end
