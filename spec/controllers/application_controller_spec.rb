# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationController do
  subject(:controller) { described_class.new }

  let(:user) { create(:user) }

  describe "#current_account" do
    it "returns the signed-in user's account" do
      allow(controller).to receive(:current_user).and_return(user)

      expect(controller.send(:current_account)).to eq(user.account)
    end

    it "returns nil when no user is signed in" do
      allow(controller).to receive(:current_user).and_return(nil)

      expect(controller.send(:current_account)).to be_nil
    end

    it "exposes current_account to views" do
      expect(described_class._helper_methods).to include(:current_account)
    end
  end
end
