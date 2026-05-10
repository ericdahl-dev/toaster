require "rails_helper"

RSpec.describe InboxIngestion::Sync do
  describe ".call" do
    context "with reconcile stubbed" do
      before do
        allow(BookingRequests::Reconcile).to receive(:call)
      end

      it "persists one normalized row and invokes checkpoint commit once" do
        account = create(:account)
        checkpoint_calls = 0
        adapter = Object.new
        adapter.define_singleton_method(:account) { account }
        adapter.define_singleton_method(:each_normalized_message) do |&block|
          block.call(
            provider: "imap",
            provider_message_id: "<one@example.com>",
            direction: "inbound",
            subject: "Hello",
            raw_payload: { "uid" => 1 }
          )
        end
        adapter.define_singleton_method(:write_checkpoint_after_batch) do |created_count:, deduped_count:, messages:|
          checkpoint_calls += 1
          nil
        end

        result = described_class.call(adapter: adapter)

        expect(result.created_count).to eq(1)
        expect(result.deduped_count).to eq(0)
        expect(result.messages.size).to eq(1)
        expect(InboxMessage.find_by!(account: account, provider: "imap", provider_message_id: "<one@example.com>").subject).to eq("Hello")
        expect(checkpoint_calls).to eq(1)
      end

      it "invokes checkpoint commit even when the adapter yields no messages" do
        account = create(:account)
        checkpoint_calls = 0
        adapter = Object.new
        adapter.define_singleton_method(:account) { account }
        adapter.define_singleton_method(:each_normalized_message) do
          # intentionally yields nothing
        end
        adapter.define_singleton_method(:write_checkpoint_after_batch) do |created_count:, deduped_count:, messages:|
          checkpoint_calls += 1
        end

        result = described_class.call(adapter: adapter)

        expect(result.created_count).to eq(0)
        expect(result.deduped_count).to eq(0)
        expect(result.messages).to be_empty
        expect(checkpoint_calls).to eq(1)
      end

      it "raises when the adapter does not implement the contract" do
        adapter = Object.new
        adapter.define_singleton_method(:account) { create(:account) }

        expect { described_class.call(adapter: adapter) }.to raise_error(ArgumentError, /missing/)
      end

      it "merges attributes when the same message is seen twice in one run" do
        account = create(:account)
        adapter = Object.new
        adapter.define_singleton_method(:account) { account }
        adapter.define_singleton_method(:each_normalized_message) do |&block|
          block.call(provider: "imap", provider_message_id: "a", direction: "inbound", subject: "First", raw_payload: {})
          block.call(provider: "imap", provider_message_id: "a", direction: "inbound", subject: "Second", raw_payload: {})
        end
        adapter.define_singleton_method(:write_checkpoint_after_batch) do |created_count:, deduped_count:, messages:|
          nil
        end

        result = described_class.call(adapter: adapter)

        expect(result.created_count).to eq(1)
        expect(result.deduped_count).to eq(1)
        expect(InboxMessage.find_by!(account: account, provider: "imap", provider_message_id: "a").subject).to eq("Second")
      end
    end

    it "calls Reconcile after each upsert so a booking request is created" do
      account = create(:account)
      adapter = Object.new
      adapter.define_singleton_method(:account) { account }
      adapter.define_singleton_method(:each_normalized_message) do |&block|
        block.call(
          provider: "imap",
          provider_message_id: "<booking@example.com>",
          direction: "inbound",
          from_email: "lead@example.com",
          from_name: "Demo Lead",
          subject: "Wedding for 120 guests on June 14, 2026",
          body_text: "Hi, we're looking for a venue on June 14, 2026 for 120 guests with a budget of $15000.",
          received_at: Time.zone.parse("2026-04-01 10:00:00 UTC"),
          raw_payload: { "uid" => 1 }
        )
      end
      adapter.define_singleton_method(:write_checkpoint_after_batch) { |_kwargs| nil }

      expect {
        described_class.call(adapter: adapter)
      }.to change(BookingRequest, :count).by(1)

      inbox_message = InboxMessage.find_by!(account: account, provider: "imap", provider_message_id: "<booking@example.com>")
      expect(inbox_message.booking_request).to be_present
      expect(EventLog.where(event_type: "booking_request.created", subject_type: "BookingRequest").count).to eq(1)
    end
  end
end
