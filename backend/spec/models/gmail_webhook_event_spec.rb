require "rails_helper"

RSpec.describe GmailWebhookEvent, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      expect(build(:gmail_webhook_event)).to be_valid
    end
  end

  describe "scopes" do
    it "returns unprocessed events" do
      account = create(:account)
      unprocessed = create(:gmail_webhook_event, account: account, processed_at: nil)
      processed = create(:gmail_webhook_event, account: account, processed_at: Time.current)
      expect(GmailWebhookEvent.unprocessed).to include(unprocessed)
      expect(GmailWebhookEvent.unprocessed).not_to include(processed)
    end

    it "returns processed events" do
      account = create(:account)
      unprocessed = create(:gmail_webhook_event, account: account, processed_at: nil)
      processed = create(:gmail_webhook_event, account: account, processed_at: Time.current)
      expect(GmailWebhookEvent.processed).to include(processed)
      expect(GmailWebhookEvent.processed).not_to include(unprocessed)
    end
  end

  describe "#processed?" do
    it "returns false when processed_at is nil" do
      event = build(:gmail_webhook_event, processed_at: nil)
      expect(event.processed?).to be false
    end

    it "returns true when processed_at is set" do
      event = build(:gmail_webhook_event, processed_at: Time.current)
      expect(event.processed?).to be true
    end
  end
end
