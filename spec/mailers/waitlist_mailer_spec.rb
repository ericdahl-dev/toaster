# frozen_string_literal: true

require "rails_helper"

RSpec.describe WaitlistMailer, type: :mailer do
  describe "#confirmation" do
    let(:entry) { build(:waitlist_entry, email: "owner@venue.com") }
    let(:mail) { described_class.confirmation(entry) }

    it "sends to the waitlist entry email" do
      expect(mail.to).to eq(["owner@venue.com"])
    end

    it "has the correct subject" do
      expect(mail.subject).to eq("You're on the Toaster waitlist")
    end

    it "is from the Toaster address" do
      expect(mail.from).to eq(["onboarding@resend.dev"])
    end

    it "includes confirmation copy in the HTML body" do
      expect(mail.html_part.body.to_s).to include("You're on the list")
    end

    it "includes confirmation copy in the text body" do
      expect(mail.text_part.body.to_s).to include("You're on the list")
    end
  end
end
