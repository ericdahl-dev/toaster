# frozen_string_literal: true

require "rails_helper"

module BookingRequests
  class TestLlmCall
    include LlmCall

    MODEL = "gpt-4o-mini"
    PROMPT_VERSION = "test-v1"
    SYSTEM_PROMPT = "You are a test assistant."
    RUN_TYPE = "classifier"
    TEMPERATURE = 0

    def parse_result(raw)
      raw["result"]
    end
  end
end

RSpec.describe BookingRequests::LlmCall do
  let(:account) { create(:account) }
  let(:booking_request) { create(:booking_request, account:) }

  subject(:instance) { BookingRequests::TestLlmCall.new(account:, booking_request:) }

  describe "#call" do
    context "when OPENAI_API_KEY is absent" do
      before { stub_const("ENV", ENV.to_h.merge("OPENAI_API_KEY" => nil)) }

      it "raises ConfigurationError" do
        expect { instance.call(subject: "test", body_text: "test") }
          .to raise_error(BookingRequests::LlmCall::ConfigurationError)
      end
    end

    context "with a valid API key" do
      before do
        stub_const("ENV", ENV.to_h.merge("OPENAI_API_KEY" => "test-key"))
        allow(instance).to receive(:call_openai).and_return({ "result" => "parsed" })
      end

      it "returns the parsed result" do
        expect(instance.call(subject: "s", body_text: "b")).to eq("parsed")
      end

      it "persists an AiRun" do
        expect { instance.call(subject: "s", body_text: "b") }.to change(AiRun, :count).by(1)
        run = AiRun.last
        expect(run.run_type).to eq("classifier")
        expect(run.llm_model).to eq("gpt-4o-mini")
        expect(run.prompt_version).to eq("test-v1")
        expect(run.account).to eq(account)
        expect(run.booking_request).to eq(booking_request)
        expect(run.latency_ms).to be_a(Integer)
      end
    end
  end
end
