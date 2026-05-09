# frozen_string_literal: true

require "rails_helper"

RSpec.describe ExpireWaitlistInvitesJob, type: :job do
  describe "#perform" do
    it "uses the default queue" do
      expect(described_class.queue_name).to eq("default")
    end

    it "flips invited entries older than Devise.reset_password_within to expired" do
      stale = create(:waitlist_entry, status: :invited, invited_at: (Devise.reset_password_within + 1.minute).ago)
      fresh = create(:waitlist_entry, status: :invited, invited_at: 1.minute.ago)

      described_class.perform_now

      expect(stale.reload).to be_expired
      expect(fresh.reload).to be_invited
    end

    it "does not touch pending or converted entries" do
      pending_entry = create(:waitlist_entry, status: :pending)
      converted_entry = create(:waitlist_entry, status: :converted, invited_at: 1.day.ago)

      described_class.perform_now

      expect(pending_entry.reload).to be_pending
      expect(converted_entry.reload).to be_converted
    end

    it "logs the number of expired entries" do
      create(:waitlist_entry, status: :invited, invited_at: (Devise.reset_password_within + 1.minute).ago)
      allow(Rails.logger).to receive(:info)

      described_class.perform_now

      expect(Rails.logger).to have_received(:info).with(include("waitlist_invites_expired"))
      expect(Rails.logger).to have_received(:info).with(include("expired_count"))
    end

    it "does nothing when there are no stale invites" do
      described_class.perform_now
    end
  end
end
