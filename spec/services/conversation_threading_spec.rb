# frozen_string_literal: true

require "rails_helper"

RSpec.describe ConversationThreading do
  describe ".canonical_id" do
    it "prefixes provider and raw inbox thread id" do
      expect(described_class.canonical_id(
        provider: "imap",
        provider_thread_id: "thread-abc",
        provider_message_id: "msg-fallback"
      )).to eq("imap:thread-abc")
    end

    it "falls back to provider_message_id when thread id is blank" do
      expect(described_class.canonical_id(
        provider: "imap",
        provider_thread_id: nil,
        provider_message_id: "msg-only"
      )).to eq("imap:msg-only")
    end
  end

  describe ".canonical_id_for" do
    it "reads fields from an inbox message" do
      message = build(:inbox_message, provider: "imap", provider_thread_id: "t1", provider_message_id: "m1")

      expect(described_class.canonical_id_for(message)).to eq("imap:t1")
    end
  end

  describe ".inbox_thread_id_from_canonical" do
    it "strips the provider prefix" do
      expect(described_class.inbox_thread_id_from_canonical("imap:thread-abc")).to eq("thread-abc")
    end

    it "returns the value unchanged when not prefixed" do
      expect(described_class.inbox_thread_id_from_canonical("legacy-thread")).to eq("legacy-thread")
    end
  end
end
