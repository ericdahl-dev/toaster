# frozen_string_literal: true

require "rails_helper"

RSpec.describe BookingRequests::Classifier do
  let(:account) { create(:account) }
  let(:booking_request) { create(:booking_request, account:) }

  def build_client(response)
    client = instance_double(OpenAI::Client)
    allow(client).to receive(:chat).and_return(
      { "choices" => [ { "message" => { "content" => response.to_json } } ] }
    )
    client
  end

  describe "#call" do
    context "when OPENAI_API_KEY is absent and no client injected" do
      before { stub_const("ENV", ENV.to_h.merge("OPENAI_API_KEY" => nil)) }

      it "raises ConfigurationError on initialize" do
        expect { described_class.new(account:, booking_request:) }
          .to raise_error(BookingRequests::Classifier::ConfigurationError)
      end
    end

    context "when client returns booking_request: true" do
      let(:classifier) { described_class.new(account:, booking_request:, client: build_client({ "booking_request" => true })) }

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

    context "when client returns booking_request: false" do
      let(:classifier) { described_class.new(account:, booking_request:, client: build_client({ "booking_request" => false })) }

      it "returns false" do
        expect(classifier.call(subject: "Out of office", body_text: "I am away")).to be false
      end

      it "still persists an AiRun" do
        expect {
          classifier.call(subject: "Out of office", body_text: "I am away")
        }.to change(AiRun, :count).by(1)
      end
    end

    context "when the client raises an error" do
      let(:classifier) do
        client = instance_double(OpenAI::Client)
        allow(client).to receive(:chat).and_raise(StandardError, "timeout")
        described_class.new(account:, booking_request:, client:)
      end

      it "raises the error" do
        expect { classifier.call(subject: "Inquiry", body_text: "Hello") }
          .to raise_error(StandardError, "timeout")
      end
    end
  end
end
