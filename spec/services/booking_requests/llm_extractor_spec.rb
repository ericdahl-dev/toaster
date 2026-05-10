# frozen_string_literal: true

require "rails_helper"

RSpec.describe BookingRequests::LlmExtractor do
  let(:account) { create(:account) }
  let(:booking_request) { create(:booking_request, account:) }

  def build_client(response)
    client = double("OpenAI::Client")
    allow(client).to receive(:chat).and_return(
      { "choices" => [ { "message" => { "content" => response.to_json } } ] }
    )
    client
  end

  let(:llm_response) do
    {
      "event_date" => "2026-06-14",
      "headcount" => 40,
      "budget" => 500.0,
      "start_time" => "7:00 PM",
      "celebration_type" => "birthday",
      "confidence" => 0.95,
      "notes" => "Guest of honor: Sarah"
    }
  end

  let(:extractor) { described_class.new(account:, booking_request:, client: build_client(llm_response)) }

  describe "#call" do
    context "when OPENAI_API_KEY is absent and no client injected" do
      before { stub_const("ENV", ENV.to_h.merge("OPENAI_API_KEY" => nil)) }

      it "raises ConfigurationError on initialize" do
        expect { described_class.new(account:, booking_request:) }
          .to raise_error(BookingRequests::LlmExtractor::ConfigurationError)
      end
    end

    context "with a valid client" do
      it "returns a result with extracted fields" do
        result = extractor.call(subject: "Party inquiry", body_text: "40 guests, June 14 2026, $500 budget")

        expect(result[:event_date]).to eq(Date.new(2026, 6, 14))
        expect(result[:headcount]).to eq(40)
        expect(result[:budget]).to eq(500.0)
        expect(result[:start_time]).to eq("7:00 PM")
        expect(result[:celebration_type]).to eq("birthday")
        expect(result[:confidence]).to eq(0.95)
        expect(result[:notes]).to eq("Guest of honor: Sarah")
      end

      it "persists an AiRun with run_type extraction" do
        expect {
          extractor.call(subject: "Party inquiry", body_text: "40 guests")
        }.to change(AiRun, :count).by(1)

        run = AiRun.last
        expect(run.run_type).to eq("extraction")
        expect(run.llm_model).to eq("gpt-4o-mini")
        expect(run.account).to eq(account)
        expect(run.booking_request).to eq(booking_request)
        expect(run.latency_ms).to be_a(Integer)
        expect(run.prompt_version).to eq("extractor-v1")
      end

      context "when LLM returns null event_date" do
        let(:llm_response) { { "event_date" => nil, "headcount" => 40, "budget" => nil, "start_time" => nil, "celebration_type" => nil, "confidence" => 0.4, "notes" => nil } }

        it "returns nil event_date" do
          result = extractor.call(subject: "Party", body_text: "40 guests")
          expect(result[:event_date]).to be_nil
        end
      end

      context "when LLM returns unparseable date" do
        let(:llm_response) { { "event_date" => "not a date", "headcount" => nil, "budget" => nil, "start_time" => nil, "celebration_type" => nil, "confidence" => 0.3, "notes" => nil } }

        it "sets event_date to nil without raising" do
          result = extractor.call(subject: "Party", body_text: "some text")
          expect(result[:event_date]).to be_nil
        end
      end

      context "when the client raises" do
        let(:extractor) do
          client = double("OpenAI::Client")
          allow(client).to receive(:chat).and_raise(StandardError, "timeout")
          described_class.new(account:, booking_request:, client:)
        end

        it "raises the error" do
          expect { extractor.call(subject: "Party", body_text: "40 guests") }
            .to raise_error(StandardError, "timeout")
        end
      end
    end
  end
end
