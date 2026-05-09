# frozen_string_literal: true

require "rails_helper"

RSpec.describe WaitlistConversionService do
  subject(:call) { described_class.call(user) }

  let(:account) { create(:account) }

  describe ".call" do
    context "when user has sign_in_count == 1 and has an invited WaitlistEntry" do
      let(:user) { create(:user, account: account, sign_in_count: 1) }
      let!(:entry) { create(:waitlist_entry, email: user.email, status: :invited, invited_at: 1.day.ago) }

      it "marks the WaitlistEntry as converted" do
        expect { call }.to change { entry.reload.status }.from("invited").to("converted")
      end
    end

    context "when user has sign_in_count > 1 (returning user)" do
      let(:user) { create(:user, account: account, sign_in_count: 2) }
      let!(:entry) { create(:waitlist_entry, email: user.email, status: :invited, invited_at: 1.day.ago) }

      it "does not change the WaitlistEntry status" do
        expect { call }.not_to change { entry.reload.status }
      end
    end

    context "when there is no matching WaitlistEntry" do
      let(:user) { create(:user, account: account, sign_in_count: 1) }

      it "does nothing" do
        expect { call }.not_to raise_error
      end
    end

    context "when WaitlistEntry exists but is not invited (e.g. pending)" do
      let(:user) { create(:user, account: account, sign_in_count: 1) }
      let!(:entry) { create(:waitlist_entry, email: user.email, status: :pending) }

      it "does not convert the entry" do
        expect { call }.not_to change { entry.reload.status }
      end
    end
  end
end
