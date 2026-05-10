# frozen_string_literal: true

require "rails_helper"

RSpec.describe Drafts::MailBuilder do
  let(:account) { create(:account) }
  let(:imap_connection) { create(:imap_connection, account: account) }
  let(:contact) { create(:contact, account: account, email: "guest@example.com") }
  let(:inbox_message) { create(:inbox_message, account: account, subject: "Party inquiry") }
  let(:thread) { create(:conversation_thread, account: account, contact: contact, subject: "Party inquiry") }
  let(:booking_request) do
    create(:booking_request,
      account: account,
      contact: contact,
      conversation_thread: thread,
      source_inbox_message: inbox_message)
  end
  let(:draft) { create(:draft, account: account, booking_request: booking_request, body: "Thank you!") }

  subject(:builder) { described_class.new(draft: draft) }

  describe "#subject_line" do
    it "returns Re: prefixed subject when original does not start with Re:" do
      expect(builder.subject_line).to eq("Re: Party inquiry")
    end

    it "does not double-prefix when subject already starts with Re:" do
      inbox_message.update!(subject: "Re: Party inquiry")
      expect(builder.subject_line).to eq("Re: Party inquiry")
    end

    it "falls back to default when no source inbox message" do
      booking_request.update!(source_inbox_message: nil)
      expect(builder.subject_line).to eq("Re: your inquiry")
    end
  end

  describe "#build_outbound_message_attrs" do
    it "returns attrs for creating an outbound Message" do
      attrs = builder.build_outbound_message_attrs(body_text: draft.body, sent_at: Time.current)
      expect(attrs[:account]).to eq(account)
      expect(attrs[:booking_request]).to eq(booking_request)
      expect(attrs[:conversation_thread]).to eq(thread)
      expect(attrs[:direction]).to eq(:outbound)
      expect(attrs[:body_text]).to eq("Thank you!")
    end
  end
end
