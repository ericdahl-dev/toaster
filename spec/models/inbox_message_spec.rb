require "rails_helper"

RSpec.describe InboxMessage, type: :model do
  describe "validations" do
    it "is valid with minimal required attributes" do
      account = create(:account)
      message = described_class.new(
        account: account,
        provider: "imap",
        provider_message_id: "msg-123",
        direction: :inbound,
        raw_payload: {"messageId" => "msg-123"}
      )

      expect(message).to be_valid
    end

    it "requires provider_message_id to be unique per account and provider" do
      account = create(:account)
      create(
        :inbox_message,
        account: account,
        provider: "imap",
        provider_message_id: "msg-123"
      )

      duplicate = build(
        :inbox_message,
        account: account,
        provider: "imap",
        provider_message_id: "msg-123"
      )

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:provider_message_id]).to include("has already been taken")
    end

    it "allows the same provider_message_id for a different provider" do
      account = create(:account)
      create(
        :inbox_message,
        account: account,
        provider: "imap",
        provider_message_id: "msg-123"
      )

      other_provider = build(
        :inbox_message,
        account: account,
        provider: "other_provider",
        provider_message_id: "msg-123"
      )

      expect(other_provider).to be_valid
    end
  end
end
