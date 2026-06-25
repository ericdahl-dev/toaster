# frozen_string_literal: true

require "rails_helper"

RSpec.describe BookingRequests::Persist do
  let(:account) { create(:account) }
  let(:inbox_message) do
    create(:inbox_message,
      account:,
      from_email: "guest@example.com",
      from_name: "Guest User",
      subject: "Party inquiry",
      body_text: "We want to book for 40 guests.")
  end

  let(:raw) do
    {
      event_date: Date.new(2026, 6, 14),
      headcount: 40,
      budget: 500.0,
      start_time: "7:00 PM",
      celebration_type: "birthday",
      confidence: 0.95,
      notes: nil
    }
  end

  describe ".call" do
    it "returns a Result with a persisted BookingRequest" do
      result = described_class.call(inbox_message:, raw:, account:)
      expect(result.booking_request).to be_persisted
    end

    it "creates a Contact for the sender" do
      expect {
        described_class.call(inbox_message:, raw:, account:)
      }.to change(Contact, :count).by(1)

      contact = Contact.last
      expect(contact.email).to eq("guest@example.com")
      expect(contact.name).to eq("Guest User")
    end

    it "creates a ConversationThread" do
      expect {
        described_class.call(inbox_message:, raw:, account:)
      }.to change(ConversationThread, :count).by(1)
    end

    it "creates a Message for the inbox_message" do
      expect {
        described_class.call(inbox_message:, raw:, account:)
      }.to change(Message, :count).by(1)
    end

    it "writes extraction fields onto the BookingRequest" do
      result = described_class.call(inbox_message:, raw:, account:)
      br = result.booking_request
      expect(br.headcount).to eq(40)
      expect(br.budget).to eq(500.0)
      expect(br.start_time).to eq("7:00 PM")
      expect(br.celebration_type).to eq("birthday")
    end

    context "when contact with same email already exists" do
      before do
        create(:contact, account:, email: "guest@example.com", name: "Old Name")
      end

      it "reuses the existing contact rather than creating a new one" do
        expect {
          described_class.call(inbox_message:, raw:, account:)
        }.not_to change(Contact, :count)
      end

      it "updates the contact name" do
        described_class.call(inbox_message:, raw:, account:)
        expect(Contact.find_by(email: "guest@example.com").name).to eq("Guest User")
      end
    end

    context "when inbox_message has no from_email" do
      let(:inbox_message) do
        create(:inbox_message, account:, from_email: nil, from_name: "Anonymous")
      end

      it "creates a new contact without email" do
        expect {
          described_class.call(inbox_message:, raw:, account:)
        }.to change(Contact, :count).by(1)
      end
    end

    context "when a RecordNotUnique race triggers the outer retry" do
      it "logs a warning on each retry attempt" do
        service = described_class.new(inbox_message:, account:)
        call_count = 0
        allow(ActiveRecord::Base).to receive(:transaction).and_wrap_original do |orig, *args, **kwargs, &block|
          call_count += 1
          raise ActiveRecord::RecordNotUnique, "duplicate" if call_count == 1
          orig.call(*args, **kwargs, &block)
        end

        expect(Rails.logger).to receive(:warn).with(hash_including("attempts", "error_class", "inbox_message_id")).at_least(:once)
        service.call(raw)
      end

      it "logs an error before re-raising when retries exhausted" do
        service = described_class.new(inbox_message:, account:)
        allow(ActiveRecord::Base).to receive(:transaction).and_raise(ActiveRecord::RecordNotUnique, "duplicate")

        expect(Rails.logger).to receive(:error).with(hash_including("attempts", "error_class", "inbox_message_id"))
        expect { service.call(raw) }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end

    context "when find_or_create_by! races a concurrent insert (RecordNotUnique rescue)" do
      before do
        create(:contact, account:, email: "guest@example.com", name: "Concurrent Winner")
      end

      it "falls back to the existing contact via find_by!" do
        # Stub find_or_create_by! to raise — simulates the moment another transaction
        # commits the same contact between our SELECT and our INSERT
        contacts_proxy = account.contacts
        allow(account).to receive(:contacts).and_return(contacts_proxy)
        allow(contacts_proxy).to receive(:find_or_create_by!).and_raise(ActiveRecord::RecordNotUnique)

        expect {
          described_class.call(inbox_message:, raw:, account:)
        }.not_to change(Contact, :count)
      end
    end

    context "when called twice with the same inbox_message" do
      it "does not create a duplicate BookingRequest" do
        described_class.call(inbox_message:, raw:, account:)
        expect {
          described_class.call(inbox_message:, raw:, account:)
        }.not_to change(BookingRequest, :count)
      end
    end

    context "when a follow-up message arrives on the same thread" do
      let(:follow_up_message) do
        create(:inbox_message,
          account:,
          from_email: "guest@example.com",
          from_name: "Guest User",
          subject: "Re: Party inquiry",
          body_text: "Actually we need 50 guests.",
          provider_thread_id: inbox_message.provider_thread_id)
      end

      before { described_class.call(inbox_message:, raw:, account:) }

      it "reuses the existing BookingRequest rather than creating a new one" do
        expect {
          described_class.call(inbox_message: follow_up_message, raw:, account:)
        }.not_to change(BookingRequest, :count)
      end

      it "attaches the follow-up Message to the existing BookingRequest" do
        result = described_class.call(inbox_message: follow_up_message, raw:, account:)
        expect(result.booking_request.messages.count).to eq(2)
      end

      it "does not create a duplicate ConversationThread" do
        expect {
          described_class.call(inbox_message: follow_up_message, raw:, account:)
        }.not_to change(ConversationThread, :count)
      end
    end
  end
end
