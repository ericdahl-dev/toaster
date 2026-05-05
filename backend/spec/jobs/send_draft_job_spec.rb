require "rails_helper"

RSpec.describe SendDraftJob, type: :job do
  describe "#perform" do
    it "enqueues a PushDraftJob for the given draft" do
      draft = create(:draft, status: :pending_review)

      expect { described_class.perform_now(draft.id) }
        .to have_enqueued_job(PushDraftJob).with(draft.id)
    end

    it "discards the job when the draft no longer exists" do
      expect { described_class.perform_now(0) }.not_to raise_error
    end

    it "uses the mailers queue" do
      expect(described_class.queue_name).to eq("mailers")
    end
  end
end
