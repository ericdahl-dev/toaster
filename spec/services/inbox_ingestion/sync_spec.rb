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

      stub_const("ENV", ENV.to_h.merge("OPENAI_API_KEY" => "test-key"))
      allow_any_instance_of(BookingRequests::Classifier).to receive(:call_openai)
        .and_return({ "booking_request" => true })
      allow_any_instance_of(BookingRequests::LlmExtractor).to receive(:call_openai)
        .and_return({
          "event_date" => "2026-06-14",
          "headcount" => 120,
          "budget" => 15000.0,
          "start_time" => nil,
          "celebration_type" => "wedding",
          "confidence" => 0.95,
          "notes" => nil
        })
      allow_any_instance_of(BookingRequests::DraftWriter).to receive(:call_openai)
        .and_return({"body" => "Thank you for your inquiry!"})

      expect {
        described_class.call(adapter: adapter)
      }.to change(BookingRequest, :count).by(1)

      inbox_message = InboxMessage.find_by!(account: account, provider: "imap", provider_message_id: "<booking@example.com>")
      expect(inbox_message.booking_request).to be_present
      expect(EventLog.where(event_type: "booking_request.created", subject_type: "BookingRequest").count).to eq(1)
    end

    context "with an adapter that has imap_connection and inbox filters" do
      it "resolves venue via FilterMatcher and passes it to Reconcile" do
        account = create(:account)
        venue = create(:venue, account: account)
        imap_connection = create(:imap_connection, account: account)
        create(:inbox_filter, imap_connection: imap_connection, venue: venue, keyword: "wedding", position: 0)

        called_with_venue = nil
        allow(BookingRequests::Reconcile).to receive(:call) do |inbox_message:, venue:|
          called_with_venue = venue
        end

        adapter = Object.new
        adapter.define_singleton_method(:account) { account }
        adapter.define_singleton_method(:imap_connection) { imap_connection }
        adapter.define_singleton_method(:each_normalized_message) do |&block|
          block.call(
            provider: "imap",
            provider_message_id: "<w@example.com>",
            direction: "inbound",
            subject: "Wedding inquiry",
            raw_payload: {}
          )
        end
        adapter.define_singleton_method(:write_checkpoint_after_batch) { |**| nil }

        described_class.call(adapter: adapter)

        expect(called_with_venue).to eq(venue)
      end

      it "passes nil venue when no filter matches" do
        account = create(:account)
        imap_connection = create(:imap_connection, account: account)

        called_with_venue = :not_called
        allow(BookingRequests::Reconcile).to receive(:call) do |inbox_message:, venue:|
          called_with_venue = venue
        end

        adapter = Object.new
        adapter.define_singleton_method(:account) { account }
        adapter.define_singleton_method(:imap_connection) { imap_connection }
        adapter.define_singleton_method(:each_normalized_message) do |&block|
          block.call(
            provider: "imap",
            provider_message_id: "<x@example.com>",
            direction: "inbound",
            subject: "Unrelated",
            raw_payload: {}
          )
        end
        adapter.define_singleton_method(:write_checkpoint_after_batch) { |**| nil }

        described_class.call(adapter: adapter)

        expect(called_with_venue).to be_nil
      end
    end
  end
end
