# frozen_string_literal: true

require "rails_helper"

RSpec.describe BookingRequests::DraftWriter do
  let(:account) { create(:account) }
  let(:booking_request) { create(:booking_request, account:) }

  def build_client(body:)
    client = double("OpenAI::Client")
    allow(client).to receive(:chat).and_return(
      { "choices" => [ { "message" => { "content" => { body: body }.to_json } } ] }
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
        expect(run.prompt_version).to eq("draft-writer-v2")
      end

      context "with venue chunks" do
        let(:draft_writer) do
          described_class.new(
            account:,
            booking_request:,
            client: build_client(body: "Great choice!"),
            venue_chunks: [ "Capacity: 200", "Pricing: from $5000" ]
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

      context "with thread history" do
        let(:history) do
          [
            { role: "user", content: "We'd like to book for 50 guests on June 15th." },
            { role: "assistant", content: "Thanks! What occasion are you celebrating?" },
            { role: "user", content: "It's a wedding reception." }
          ]
        end

        let(:draft_writer) do
          described_class.new(account:, booking_request:, client: build_client(body: "Wonderful!"))
        end

        it "sends thread history messages to the LLM in correct order" do
          sent_messages = nil
          allow(draft_writer.__send__(:client)).to receive(:chat) do |params|
            sent_messages = params[:parameters][:messages]
            { "choices" => [ { "message" => { "content" => { body: "Wonderful!" }.to_json } } ] }
          end

          draft_writer.call(subject: "Re: inquiry", body_text: "It's a wedding reception.", thread_history: history)

          expect(sent_messages).to be_an(Array)
          roles = sent_messages.map { |m| m[:role] }
          expect(roles.first).to eq("system")
          expect(roles).to include("user", "assistant")
          # history turns appear before final user message
          history_portion = sent_messages[1..]
          expect(history_portion.map { |m| m[:role] }).to eq(%w[user assistant user user])
        end

        it "still persists an AiRun" do
          expect {
            draft_writer.call(subject: "Re: inquiry", body_text: "Wedding reception.", thread_history: history)
          }.to change(AiRun, :count).by(1)
        end
      end

      context "with missing fields on the booking request" do
        let(:booking_request) { create(:booking_request, account:, missing_fields: %w[event_date headcount]) }

        let(:draft_writer) do
          described_class.new(account:, booking_request:, client: build_client(body: "Please share the date!"))
        end

        it "includes missing fields in the system prompt" do
          sent_messages = nil
          allow(draft_writer.__send__(:client)).to receive(:chat) do |params|
            sent_messages = params[:parameters][:messages]
            { "choices" => [ { "message" => { "content" => { body: "Please share the date!" }.to_json } } ] }
          end

          draft_writer.call(subject: "Inquiry", body_text: "Hi!")

          system_msg = sent_messages.find { |m| m[:role] == "system" }
          expect(system_msg[:content]).to include("event_date", "headcount")
        end
      end

      context "when no fields are missing" do
        let(:booking_request) { create(:booking_request, account:, missing_fields: []) }

        let(:draft_writer) do
          described_class.new(account:, booking_request:, client: build_client(body: "All set!"))
        end

        it "does not include a missing fields list in the system prompt" do
          sent_messages = nil
          allow(draft_writer.__send__(:client)).to receive(:chat) do |params|
            sent_messages = params[:parameters][:messages]
            { "choices" => [ { "message" => { "content" => { body: "All set!" }.to_json } } ] }
          end

          draft_writer.call(subject: "Inquiry", body_text: "Hi!")

          system_msg = sent_messages.find { |m| m[:role] == "system" }
          expect(system_msg[:content]).not_to include("Still need:")
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
