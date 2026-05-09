require "rails_helper"

RSpec.describe BookingRequests::Reconcile do
  describe ".call" do
    let(:account) { create(:account) }

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

    context "when creating a new booking request" do
      it "creates a BookingRequest" do
        inbox_message = build_inbox_message
        expect {
          described_class.call(inbox_message: inbox_message)
        }.to change(BookingRequest, :count).by(1)
      end

      it "returns the persisted booking request" do
        inbox_message = build_inbox_message
        result = described_class.call(inbox_message: inbox_message)
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

      it "includes missing_fields and review_reasons in the EventLog payload and creates a review task" do
        inbox_message = create(
          :inbox_message,
          account: account,
          from_email: "taylor@example.com",
          subject: "Private event inquiry",
          body_text: "We'd like to learn more about availability."
        )

        expect {
          described_class.call(inbox_message: inbox_message)
        }.to change(Task, :count).by(1)

        log = EventLog.last
        expect(log.payload).to include(
          "status" => "reviewing",
          "missing_fields" => match_array(%w[event_date headcount budget_cents])
        )
      end
    end

    context "when a review is required" do
      it "creates a review Task when booking request is in reviewing status" do
        inbox_message = create(
          :inbox_message,
          account: account,
          from_email: "taylor@example.com",
          subject: "Private event inquiry",
          body_text: "We'd like to learn more about availability."
        )

        expect {
          described_class.call(inbox_message: inbox_message)
        }.to change(Task, :count).by(1)

        task = Task.last
        expect(task.account).to eq(account)
        expect(task.title).to eq(BookingRequests::Reconcile::REVIEW_TASK_TITLE)
        expect(task.status).to eq("open")
      end

      it "does not create a duplicate review task on re-reconciliation" do
        inbox_message = create(
          :inbox_message,
          account: account,
          from_email: "taylor@example.com",
          subject: "Private event inquiry",
          body_text: "We'd like to learn more about availability."
        )

        described_class.call(inbox_message: inbox_message)

        expect {
          described_class.call(inbox_message: inbox_message)
        }.not_to change(Task, :count)
      end

      it "does not create a Task when booking request is in pending status" do
        inbox_message = build_inbox_message
        expect {
          described_class.call(inbox_message: inbox_message)
        }.not_to change(Task, :count)
      end
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
