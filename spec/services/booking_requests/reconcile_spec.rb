require "rails_helper"

RSpec.describe BookingRequests::Reconcile do
  describe ".call" do
    let(:account) { create(:account) }

    let(:full_extractor_response) do
      {
        "event_date" => "2026-06-14",
        "headcount" => 120,
        "budget" => 15000.0,
        "start_time" => nil,
        "celebration_type" => "wedding",
        "confidence" => 0.95,
        "notes" => nil
      }
    end

    let(:vague_extractor_response) do
      {
        "event_date" => nil,
        "headcount" => nil,
        "budget" => nil,
        "start_time" => nil,
        "celebration_type" => nil,
        "confidence" => 0.4,
        "notes" => nil
      }
    end

    before do
      stub_const("ENV", ENV.to_h.merge("OPENAI_API_KEY" => "test-key"))
      allow_any_instance_of(BookingRequests::Classifier).to receive(:call_openai)
        .and_return({ "booking_request" => true })
      allow_any_instance_of(BookingRequests::LlmExtractor).to receive(:call_openai)
        .and_return(full_extractor_response)
    end

    def build_inbox_message(overrides = {})
      create(
        :inbox_message,
        account: account,
        from_name: "Jamie Lead",
        from_email: "jamie@example.com",
        subject: "Wedding for 120 guests on June 14, 2026",
        body_text: "Hi, we're looking for a venue for 120 guests on June 14, 2026 with a budget of $15000.",
        received_at: Time.zone.parse("2026-04-01 10:00:00 UTC"),
        **overrides
      )
    end

    def build_vague_inbox_message
      create(
        :inbox_message,
        account: account,
        from_email: "taylor@example.com",
        subject: "Private event inquiry",
        body_text: "We'd like to learn more about availability."
      )
    end

    context "when creating a new booking request" do
      it "creates a BookingRequest" do
        expect {
          described_class.call(inbox_message: build_inbox_message)
        }.to change(BookingRequest, :count).by(1)
      end

      it "returns the persisted booking request" do
        result = described_class.call(inbox_message: build_inbox_message)
        expect(result).to be_a(BookingRequest)
        expect(result).to be_persisted
      end

      it "records a booking_request.created EventLog entry" do
        inbox_message = build_inbox_message
        expect {
          described_class.call(inbox_message: inbox_message)
        }.to change(EventLog, :count).by(1)

        log = EventLog.last
        expect(log.event_type).to eq("booking_request.created")
        expect(log.subject_type).to eq("BookingRequest")
        expect(log.payload).to include("status" => "pending")
      end

      it "includes missing_fields in the EventLog payload and creates a review task when fields are missing" do
        allow_any_instance_of(BookingRequests::LlmExtractor).to receive(:call_openai)
          .and_return(vague_extractor_response)

        expect {
          described_class.call(inbox_message: build_vague_inbox_message)
        }.to change(Task, :count).by(1)

        log = EventLog.last
        expect(log.payload).to include(
          "status" => "reviewing",
          "missing_fields" => match_array(%w[event_date headcount budget])
        )
      end
    end

    context "when a review is required" do
      before do
        allow_any_instance_of(BookingRequests::LlmExtractor).to receive(:call_openai)
          .and_return(vague_extractor_response)
      end

      it "creates a review Task when booking request is in reviewing status" do
        expect {
          described_class.call(inbox_message: build_vague_inbox_message)
        }.to change(Task, :count).by(1)

        task = Task.last
        expect(task.account).to eq(account)
        expect(task.title).to eq(BookingRequests::Reconcile::REVIEW_TASK_TITLE)
        expect(task.status).to eq("open")
      end

      it "does not create a duplicate review task on re-reconciliation" do
        inbox_message = build_vague_inbox_message
        described_class.call(inbox_message: inbox_message)

        expect {
          described_class.call(inbox_message: inbox_message)
        }.not_to change(Task, :count)
      end
    end

    it "does not create a Task when booking request is in pending status" do
      expect {
        described_class.call(inbox_message: build_inbox_message)
      }.not_to change(Task, :count)
    end

    context "when updating an existing booking request" do
      it "records a booking_request.updated EventLog entry on re-reconciliation" do
        inbox_message = build_inbox_message
        described_class.call(inbox_message: inbox_message)

        expect {
          described_class.call(inbox_message: inbox_message)
        }.to change(EventLog, :count).by(1)

        log = EventLog.last
        expect(log.event_type).to eq("booking_request.updated")
        expect(log.subject_type).to eq("BookingRequest")
      end

      it "does not create a new BookingRequest on re-reconciliation" do
        inbox_message = build_inbox_message
        described_class.call(inbox_message: inbox_message)

        expect {
          described_class.call(inbox_message: inbox_message)
        }.not_to change(BookingRequest, :count)
      end
    end

    context "when extraction raises an error" do
      it "rolls back the transaction and propagates the error" do
        inbox_message = build_inbox_message

        allow(BookingRequests::Extract).to receive(:call).and_raise(StandardError, "extraction failed")

        expect {
          described_class.call(inbox_message: inbox_message)
        }.to raise_error(StandardError, "extraction failed")

        expect(BookingRequest.count).to eq(0)
        expect(EventLog.count).to eq(0)
      end
    end
  end
end
