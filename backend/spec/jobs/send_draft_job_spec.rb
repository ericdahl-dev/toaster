require "rails_helper"

RSpec.describe SendDraftJob, type: :job do
  describe "#perform" do
    it "marks an approved draft as sent" do
      draft = create(:draft, status: :approved)

      described_class.perform_now(draft.id)

      draft.reload
      expect(draft.status).to eq("sent")
      expect(draft.sent_at).to be_present
    end

    it "does nothing when draft is not approved" do
      draft = create(:draft, status: :pending_review)

      described_class.perform_now(draft.id)

      expect(draft.reload.status).to eq("pending_review")
    end

    it "discards the job when the draft no longer exists" do
      expect { described_class.perform_now(0) }.not_to raise_error
    end

    it "uses the mailers queue" do
      expect(described_class.queue_name).to eq("mailers")
    end
  end
end
