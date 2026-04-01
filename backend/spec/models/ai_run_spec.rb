require "rails_helper"

RSpec.describe AiRun, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      expect(build(:ai_run)).to be_valid
    end

    it "is invalid without a model_name" do
      expect(build(:ai_run, model_name: nil)).not_to be_valid
    end

    it "is invalid without a prompt" do
      expect(build(:ai_run, prompt: nil)).not_to be_valid
    end

    it "is valid without a booking_request" do
      expect(build(:ai_run, booking_request: nil)).to be_valid
    end

    it "is invalid when booking_request belongs to different account" do
      account = create(:account)
      other_account = create(:account)
      other_contact = create(:contact, account: other_account)
      other_thread = create(:conversation_thread, account: other_account, contact: other_contact)
      other_br = create(:booking_request, account: other_account, contact: other_contact, conversation_thread: other_thread)
      ai_run = build(:ai_run, account: account, booking_request: other_br)
      expect(ai_run).not_to be_valid
      expect(ai_run.errors[:booking_request]).to include("must belong to the same account")
    end
  end

  describe "associations" do
    it "belongs to account" do
      ai_run = create(:ai_run)
      expect(ai_run.account).to be_a(Account)
    end

    it "optionally belongs to booking_request" do
      account = create(:account)
      ai_run = create(:ai_run, account: account, booking_request: nil)
      expect(ai_run.booking_request).to be_nil
    end
  end
end
