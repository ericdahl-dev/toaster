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

  def build_client(response)
    client = double("OpenAI::Client")
    allow(client).to receive(:chat).and_return(
      {
        "choices" => [ { "message" => { "content" => response.to_json } } ],
        "usage" => { "prompt_tokens" => 10, "completion_tokens" => 5 }
      }
    )
    client
  end

  subject(:instance) { BookingRequests::TestLlmCall.new(account:, booking_request:, client: build_client({ "result" => "parsed" })) }

  describe "#call" do
    context "when OPENAI_API_KEY is absent and no client injected" do
      before { stub_const("ENV", ENV.to_h.merge("OPENAI_API_KEY" => nil)) }

      it "raises ConfigurationError on initialize" do
        expect { BookingRequests::TestLlmCall.new(account:, booking_request:) }
          .to raise_error(BookingRequests::LlmCall::ConfigurationError)
      end
    end

    context "with an injected client" do
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
