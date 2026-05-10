# frozen_string_literal: true

require "rails_helper"

RSpec.describe EmailBody::Strip do
  subject(:result) { described_class.call(body) }

  describe ".call" do
    context "when body is clean" do
      let(:body) { "Hi, I'd like to book a private event for 40 guests on June 14." }

      it "returns the body unchanged" do
        expect(result).to eq(body)
      end
    end

    context "when body has a quoted reply header" do
      let(:body) do
        <<~EMAIL
          Thanks for getting back to me!

          On Mon, May 5, 2026 at 3:00 PM Jane Smith <jane@venue.com> wrote:
          > Sure, we'd love to host your event.
        EMAIL
      end

      it "strips the quoted reply" do
        expect(result).to eq("Thanks for getting back to me!")
      end
    end

    context "when body has an original message block" do
      let(:body) do
        <<~EMAIL
          Interested in booking for 50 people.

          -- Original Message --
          From: venue@example.com
          Subject: Re: Inquiry
        EMAIL
      end

      it "strips the original message block" do
        expect(result).to eq("Interested in booking for 50 people.")
      end
    end

    context "when body has an email signature" do
      let(:body) do
        <<~EMAIL
          We'd love to book your east room.

          --#{' '}
          John Doe
          CEO, Example Corp
        EMAIL
      end

      it "strips the signature" do
        expect(result).to eq("We'd love to book your east room.")
      end
    end

    context "when body is an out-of-office auto-reply" do
      let(:body) { "Out of office: I am away until Monday." }

      it "returns the body as-is (filtering is the classifier's job)" do
        expect(result).to eq("Out of office: I am away until Monday.")
      end
    end

    context "when body is nil" do
      let(:body) { nil }

      it "returns empty string" do
        expect(result).to eq("")
      end
    end

    context "when body is empty" do
      let(:body) { "" }

      it "returns empty string" do
        expect(result).to eq("")
      end
    end
  end
end
