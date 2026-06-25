# frozen_string_literal: true

require "rails_helper"

RSpec.describe Drafts::SmtpSender do
  let(:account) { create(:account) }
  let(:imap_connection) do
    create(:imap_connection, account: account,
      host: "imap.example.com", username: "sender@example.com",
      smtp_host: nil, smtp_port: nil)
  end
  let(:booking_request) { create(:booking_request, account: account) }
  let(:draft) do
    create(:draft, account: account, booking_request: booking_request,
      body: "Thanks for your inquiry!", status: "pending_review")
  end

  subject(:sender) { described_class.new(draft: draft, imap_connection: imap_connection) }

  describe "#effective_smtp_host" do
    it "returns smtp_host when set" do
      imap_connection.smtp_host = "smtp.custom.com"
      expect(sender.effective_smtp_host).to eq("smtp.custom.com")
    end

    it "derives smtp host from imap host by replacing 'imap.' with 'smtp.'" do
      expect(sender.effective_smtp_host).to eq("smtp.example.com")
    end

    it "falls back to imap host when no imap. prefix" do
      imap_connection.host = "mail.example.com"
      expect(sender.effective_smtp_host).to eq("mail.example.com")
    end
  end

  describe "#effective_smtp_port" do
    it "returns smtp_port when set" do
      imap_connection.smtp_port = 25
      expect(sender.effective_smtp_port).to eq(25)
    end

    it "defaults to 587" do
      expect(sender.effective_smtp_port).to eq(587)
    end
  end

  describe "#call" do
    let(:mail_double) { instance_double(Mail::Message, deliver!: true) }

    before do
      allow(sender).to receive(:build_mail).and_return(mail_double)
    end

    it "calls deliver! on the mail message" do
      expect(mail_double).to receive(:deliver!)
      sender.call
    end

    it "marks draft as sent" do
      sender.call
      expect(draft.reload.status).to eq("sent")
    end

    it "records sent_at on the draft" do
      sender.call
      expect(draft.reload.sent_at).to be_present
    end

    context "when send fails" do
      before { allow(mail_double).to receive(:deliver!).and_raise(Net::SMTPAuthenticationError.new("auth failed")) }

      it "raises SmtpSender::SendError" do
        expect { sender.call }.to raise_error(Drafts::SmtpSender::SendError)
      end

      it "does not mark draft as sent" do
        begin
          sender.call
        rescue Drafts::SmtpSender::SendError
          nil
        end
        expect(draft.reload.status).to eq("pending_review")
      end
    end

    Drafts::SmtpSender::SMTP_ERRORS.each do |error_class|
      it "wraps #{error_class} in SendError" do
        allow(mail_double).to receive(:deliver!).and_raise(error_class, "failure")
        expect { sender.call }.to raise_error(Drafts::SmtpSender::SendError)
      end
    end
  end

  describe ".call (class method)" do
    let(:mail_double) { instance_double(Mail::Message, deliver!: true) }

    before do
      allow_any_instance_of(described_class).to receive(:build_mail).and_return(mail_double)
    end

    it "delegates to an instance and returns after marking draft sent" do
      described_class.call(draft: draft, imap_connection: imap_connection)
      expect(draft.reload.status).to eq("sent")
    end
  end

  describe "#build_mail (private)" do
    let(:contact) { create(:contact, email: "guest@venue.com", account: account) }
    let(:booking_request_with_contact) { create(:booking_request, account: account, contact: contact) }
    let(:draft_with_contact) do
      create(:draft, account: account, booking_request: booking_request_with_contact,
        body: "Hello guest!", status: "pending_review")
    end
    let(:sender_with_contact) { described_class.new(draft: draft_with_contact, imap_connection: imap_connection) }

    it "sets from to the IMAP connection username" do
      mail = sender_with_contact.send(:build_mail)
      expect(mail.from.first).to eq("sender@example.com")
    end

    it "sets to to the contact email" do
      mail = sender_with_contact.send(:build_mail)
      expect(mail.to.first).to eq("guest@venue.com")
    end

    it "sets body to the draft body" do
      mail = sender_with_contact.send(:build_mail)
      expect(mail.body.decoded).to include("Hello guest!")
    end

    it "configures SMTP with the effective host and port" do
      mail = sender_with_contact.send(:build_mail)
      smtp_settings = mail.delivery_method.settings
      expect(smtp_settings[:address]).to eq("smtp.example.com")
      expect(smtp_settings[:port]).to eq(587)
    end

    it "does not enable SSL on port 587" do
      mail = sender_with_contact.send(:build_mail)
      smtp_settings = mail.delivery_method.settings
      expect(smtp_settings[:ssl]).to be false
      expect(smtp_settings[:enable_starttls_auto]).to be true
    end

    it "enables SSL on port 465" do
      imap_connection.smtp_port = 465
      mail = sender_with_contact.send(:build_mail)
      smtp_settings = mail.delivery_method.settings
      expect(smtp_settings[:ssl]).to be true
      expect(smtp_settings[:enable_starttls_auto]).to be false
    end
  end
end
