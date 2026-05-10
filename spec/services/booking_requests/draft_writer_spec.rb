# frozen_string_literal: true

require "rails_helper"

RSpec.describe BookingRequests::DraftWriter do
  let(:account) { create(:account) }
  let(:booking_request) { create(:booking_request, account:) }

  def build_client(body:)
    client = double("OpenAI::Client")
    allow(client).to receive(:chat).and_return(
      {"choices" => [{"message" => {"content" => {body: body}.to_json}}]}
    )
    client
  end

  describe "#call" do
    context "when OPENAI_API_KEY is absent and no client injected" do
      before { stub_const("ENV", ENV.to_h.merge("OPENAI_API_KEY" => nil)) }

      it "raises ConfigurationError on initialize" do
        expect { described_class.new(account:, booking_request:) }
          .to raise_error(BookingRequests::DraftWriter::ConfigurationError)
      end
    end

    context "with a valid client" do
      before { allow_any_instance_of(described_class).to receive(:call_openai).and_call_original }

      let(:draft_writer) do
        described_class.new(account:, booking_request:, client: build_client(body: "Thank you for your inquiry!"))
      end

      it "returns the body text from the LLM response" do
        result = draft_writer.call(subject: "Event inquiry", body_text: "We want to book for 50 guests.")
        expect(result).to eq("Thank you for your inquiry!")
      end

      it "persists an AiRun with run_type draft_writer" do
        expect {
          draft_writer.call(subject: "Event inquiry", body_text: "We want to book for 50 guests.")
        }.to change(AiRun, :count).by(1)

        run = AiRun.last
        expect(run.run_type).to eq("draft_writer")
        expect(run.llm_model).to eq("gpt-4o-mini")
        expect(run.account).to eq(account)
        expect(run.booking_request).to eq(booking_request)
        expect(run.prompt_version).to eq("draft-writer-v1")
      end

      context "with venue chunks" do
        let(:draft_writer) do
          described_class.new(
            account:,
            booking_request:,
            client: build_client(body: "Great choice!"),
            venue_chunks: ["Capacity: 200", "Pricing: from $5000"]
          )
        end

        it "includes venue context in the prompt" do
          expect_any_instance_of(described_class).to receive(:build_prompt)
            .with(subject: "Event inquiry", body_text: "50 guests")
            .and_call_original
          draft_writer.call(subject: "Event inquiry", body_text: "50 guests")
        end

        it "records rag_chunk_count on the AiRun" do
          draft_writer.call(subject: "Event inquiry", body_text: "50 guests")
          expect(AiRun.last.rag_chunk_count).to eq(2)
        end
      end

      context "when the client raises" do
        before { allow_any_instance_of(described_class).to receive(:call_openai).and_call_original }

        let(:draft_writer) do
          client = double("OpenAI::Client")
          allow(client).to receive(:chat).and_raise(StandardError, "timeout")
          described_class.new(account:, booking_request:, client:)
        end

        it "raises the error" do
          expect { draft_writer.call(subject: "Inquiry", body_text: "Hello") }
            .to raise_error(StandardError, "timeout")
        end
      end
    end
  end
end
