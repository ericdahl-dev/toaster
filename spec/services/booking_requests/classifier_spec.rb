# frozen_string_literal: true

require "rails_helper"

RSpec.describe BookingRequests::Classifier do
  let(:account) { create(:account) }
  let(:booking_request) { create(:booking_request, account:) }

  subject(:classifier) { described_class.new(account:, booking_request:) }

  describe "#call" do
    context "when OPENAI_API_KEY is absent" do
      before { stub_const("ENV", ENV.to_h.merge("OPENAI_API_KEY" => nil)) }

      it "raises ConfigurationError" do
        expect { classifier.call(subject: "Party inquiry", body_text: "We want to book") }
          .to raise_error(BookingRequests::Classifier::ConfigurationError)
      end
    end

    context "when OpenAI returns booking_request: true" do
      before do
        stub_const("ENV", ENV.to_h.merge("OPENAI_API_KEY" => "test-key"))
        allow(classifier).to receive(:call_openai).and_return({"booking_request" => true})
      end

      it "returns true" do
        expect(classifier.call(subject: "Party inquiry", body_text: "We want to book 40 guests")).to be true
      end

      it "persists an AiRun with run_type classifier" do
        expect {
          classifier.call(subject: "Party inquiry", body_text: "We want to book 40 guests")
        }.to change(AiRun, :count).by(1)

        run = AiRun.last
        expect(run.run_type).to eq("classifier")
        expect(run.llm_model).to eq("gpt-4o-mini")
        expect(run.account).to eq(account)
        expect(run.booking_request).to eq(booking_request)
        expect(run.latency_ms).to be_a(Integer)
      end
    end

    context "when OpenAI returns booking_request: false" do
      before do
        stub_const("ENV", ENV.to_h.merge("OPENAI_API_KEY" => "test-key"))
        allow(classifier).to receive(:call_openai).and_return({"booking_request" => false})
      end

      it "returns false" do
        expect(classifier.call(subject: "Out of office", body_text: "I am away")).to be false
      end

      it "still persists an AiRun" do
        expect {
          classifier.call(subject: "Out of office", body_text: "I am away")
        }.to change(AiRun, :count).by(1)
      end
    end

    context "when OpenAI call raises an error" do
      before do
        stub_const("ENV", ENV.to_h.merge("OPENAI_API_KEY" => "test-key"))
        allow(classifier).to receive(:call_openai).and_raise(StandardError, "timeout")
      end

      it "raises the error" do
        expect { classifier.call(subject: "Inquiry", body_text: "Hello") }
          .to raise_error(StandardError, "timeout")
      end
    end
  end
end
