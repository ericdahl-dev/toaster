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
      allow_any_instance_of(BookingRequests::DraftWriter).to receive(:call_openai)
        .and_return({ "body" => "Thank you for your inquiry!" })
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
      it "creates a Draft in pending_review status" do
        expect {
          described_class.call(inbox_message: build_inbox_message)
        }.to change(Draft, :count).by(1)

        draft = Draft.last
        expect(draft.status).to eq("pending_review")
        expect(draft.body).to eq("Thank you for your inquiry!")
      end

      it "does not create a second Draft on re-reconciliation" do
        inbox_message = build_inbox_message
        described_class.call(inbox_message: inbox_message)

        expect {
          described_class.call(inbox_message: inbox_message)
        }.not_to change(Draft, :count)
      end

      it "creates a BookingRequest" do
        expect {
          described_class.call(inbox_message: build_inbox_message)
        }.to change(BookingRequest, :count).by(1)
      end

      it "returns a Result with the persisted booking request" do
        result = described_class.call(inbox_message: build_inbox_message)
        expect(result).to be_a(BookingRequests::Reconcile::Result)
        expect(result.booking_request).to be_a(BookingRequest)
        expect(result.booking_request).to be_persisted
      end

      it "returns draft_created: true when a draft was created" do
        result = described_class.call(inbox_message: build_inbox_message)
        expect(result.draft_created).to be(true)
      end

      it "returns draft_created: false on re-reconciliation" do
        inbox_message = build_inbox_message
        described_class.call(inbox_message: inbox_message)
        result = described_class.call(inbox_message: inbox_message)
        expect(result.draft_created).to be(false)
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

    context "when there is prior conversation history" do
      it "assembles thread history from prior messages and sent drafts" do
        inbox_message = build_inbox_message
        result = described_class.call(inbox_message: inbox_message)
        booking_request = result.booking_request

        prior_message = create(:message,
          account: booking_request.account,
          booking_request: booking_request,
          conversation_thread: booking_request.conversation_thread,
          direction: "inbound",
          body_text: "Earlier guest message",
          sent_at: 2.hours.ago)

        sent_draft = booking_request.drafts.first
        sent_draft.update!(status: "sent")

        reconciler = described_class.new(inbox_message: inbox_message)
        history = reconciler.send(:build_thread_history, booking_request)

        expect(history).to be_an(Array)
        expect(history).not_to be_empty
        roles = history.map { |h| h[:role] }
        expect(roles).to include("user")
        expect(roles).to include("assistant")

        inbound_turn = history.find { |h| h[:content] == prior_message.body_text }
        expect(inbound_turn).not_to be_nil
        expect(inbound_turn[:role]).to eq("user")

        assistant_turn = history.find { |h| h[:role] == "assistant" }
        expect(assistant_turn[:content]).to eq(sent_draft.body)
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

    context "when a follow-up message arrives on the same thread" do
      let(:first_message) { build_inbox_message }
      let(:follow_up_message) do
        create(
          :inbox_message,
          account: account,
          from_name: "Jamie Lead",
          from_email: "jamie@example.com",
          subject: "Re: Wedding for 120 guests on June 14, 2026",
          body_text: "Actually we only need 80 guests.",
          received_at: Time.zone.parse("2026-04-02 10:00:00 UTC"),
          provider_thread_id: first_message.provider_thread_id
        )
      end

      before { described_class.call(inbox_message: first_message) }

      it "does not create a new BookingRequest for the follow-up" do
        expect {
          described_class.call(inbox_message: follow_up_message)
        }.not_to change(BookingRequest, :count)
      end

      it "creates a new draft for the follow-up reply after the pending draft is approved" do
        first_result = described_class.call(inbox_message: first_message)
        first_result.booking_request.drafts.pending_review.update_all(status: "sent")

        expect {
          described_class.call(inbox_message: follow_up_message)
        }.to change(Draft, :count).by(1)
      end

      it "does not create a duplicate draft when a pending_review draft already exists" do
        result = described_class.call(inbox_message: follow_up_message)
        pending_draft = result.booking_request.drafts.pending_review.last

        expect(pending_draft).not_to be_nil

        expect {
          described_class.call(inbox_message: follow_up_message)
        }.not_to change(Draft, :count)
      end

      it "logs booking_request.updated for the follow-up" do
        described_class.call(inbox_message: follow_up_message)
        log = EventLog.last
        expect(log.event_type).to eq("booking_request.updated")
      end

      it "includes prior outbound draft in thread history for the AI" do
        first_result = described_class.call(inbox_message: first_message)
        first_result.booking_request.drafts.last.update!(status: "sent")

        reconciler = described_class.new(inbox_message: follow_up_message)
        history = reconciler.send(:build_thread_history, first_result.booking_request)

        roles = history.map { |h| h[:role] }
        expect(roles).to include("assistant")
      end
    end

    context "when the booking request is archived" do
      let(:first_message) { build_inbox_message }
      let(:follow_up_message) do
        create(
          :inbox_message,
          account: account,
          from_name: "Jamie Lead",
          from_email: "jamie@example.com",
          subject: "Re: Wedding for 120 guests on June 14, 2026",
          body_text: "Following up on our date.",
          received_at: Time.zone.parse("2026-04-02 10:00:00 UTC"),
          provider_thread_id: first_message.provider_thread_id
        )
      end

      before do
        described_class.call(inbox_message: first_message)
        BookingRequest.last.update!(archived_at: 1.hour.ago)
      end

      it "unarchives on inbound follow-up reconcile when the inbox message is newly created" do
        described_class.call(inbox_message: follow_up_message, inbox_message_created: true)

        expect(BookingRequest.last.reload.archived_at).to be_nil
        expect(EventLog.where(event_type: "booking_request.unarchived").count).to eq(1)
      end

      it "does not unarchive on deduped re-reconcile of the same inbox message" do
        described_class.call(inbox_message: follow_up_message, inbox_message_created: true)
        BookingRequest.last.update!(archived_at: 1.hour.ago)

        described_class.call(inbox_message: follow_up_message, inbox_message_created: false)

        expect(BookingRequest.last.reload.archived_at).to be_present
        expect(EventLog.where(event_type: "booking_request.unarchived").count).to eq(1)
      end
    end

    context "when the booking request has a terminal status (extraction lock)" do
      let(:first_message) { build_inbox_message }
      let(:follow_up_message) do
        create(
          :inbox_message,
          account: account,
          from_name: "Jamie Lead",
          from_email: "jamie@example.com",
          subject: "Re: Wedding for 120 guests on June 14, 2026",
          body_text: "Actually we only need 80 guests.",
          received_at: Time.zone.parse("2026-04-02 10:00:00 UTC"),
          provider_thread_id: first_message.provider_thread_id
        )
      end

      let(:updated_extractor_response) do
        full_extractor_response.merge("headcount" => 80)
      end

      before do
        described_class.call(inbox_message: first_message)
        BookingRequest.last.update!(status: :confirmed, headcount: 120)
      end

      it "does not change extraction fields on inbound mail" do
        expect {
          described_class.call(inbox_message: follow_up_message)
        }.not_to change { BookingRequest.last.reload.headcount }
      end

      it "still creates a canonical Message for the inbound mail" do
        expect {
          described_class.call(inbox_message: follow_up_message)
        }.to change(Message, :count).by(1)
      end

      it "does not run classifier or extraction AiRuns" do
        expect {
          described_class.call(inbox_message: follow_up_message)
        }.not_to change(AiRun, :count)
      end

      it "does not create a draft or booking_request.updated log" do
        expect {
          described_class.call(inbox_message: follow_up_message)
        }.not_to change(Draft, :count)

        expect(EventLog.last.event_type).to eq("booking_request.inbound_recorded")
      end

      it "still unarchives when archived and inbox_message_created" do
        BookingRequest.last.update!(archived_at: 1.hour.ago)

        described_class.call(inbox_message: follow_up_message, inbox_message_created: true)

        expect(BookingRequest.last.reload.archived_at).to be_nil
        expect(BookingRequest.last.status).to eq("confirmed")
      end

      it "runs extraction again after status returns to reviewing" do
        allow_any_instance_of(BookingRequests::LlmExtractor).to receive(:call_openai)
          .and_return(updated_extractor_response)

        BookingRequest.last.update!(status: :reviewing)

        described_class.call(inbox_message: follow_up_message)

        expect(BookingRequest.last.reload.headcount).to eq(80)
      end
    end

    context "venue assignment" do
      it "assigns venue when it belongs to the same account" do
        inbox_message = build_inbox_message
        venue = create(:venue, account: account)

        described_class.call(inbox_message: inbox_message, venue: venue, inbox_message_created: true)

        expect(BookingRequest.last.venue_id).to eq(venue.id)
      end

      it "does not assign a venue from another account" do
        inbox_message = build_inbox_message
        other_venue = create(:venue, account: create(:account))

        described_class.call(inbox_message: inbox_message, venue: other_venue, inbox_message_created: true)

        expect(BookingRequest.last.venue_id).to be_nil
      end
    end

    context "when classifier returns false" do
      before do
        allow_any_instance_of(BookingRequests::Classifier).to receive(:call_openai)
          .and_return({ "booking_request" => false })
      end

      it "returns nil without creating a BookingRequest" do
        expect(described_class.call(inbox_message: build_inbox_message)).to be_nil
        expect(BookingRequest.count).to eq(0)
      end
    end

    context "when extraction raises an error" do
      it "rolls back the transaction and propagates the error" do
        inbox_message = build_inbox_message

        allow_any_instance_of(BookingRequests::LlmExtractor).to receive(:call_openai)
          .and_raise(StandardError, "extraction failed")

        expect {
          described_class.call(inbox_message: inbox_message)
        }.to raise_error(StandardError, "extraction failed")

        expect(BookingRequest.count).to eq(0)
        expect(EventLog.count).to eq(0)
      end
    end

    context "when venue is provided" do
      let(:venue) { create(:venue, account:) }

      before do
        allow(BookingRequests::VenueRagRetriever).to receive(:call).and_return([ "The Rooftop holds 150 guests." ])
      end

      it "calls VenueRagRetriever with the venue and query" do
        described_class.call(inbox_message: build_inbox_message, venue: venue)
        expect(BookingRequests::VenueRagRetriever).to have_received(:call).with(
          venue: venue,
          query: a_string_including("Wedding for 120 guests on June 14, 2026")
        )
      end

      it "passes retrieved chunks to LlmExtractor via rag_chunk_count on AiRun" do
        described_class.call(inbox_message: build_inbox_message, venue: venue)
        extraction_run = AiRun.where(run_type: "extraction").last
        expect(extraction_run.rag_chunk_count).to eq(1)
      end
    end

    context "when no venue is provided" do
      it "does not call VenueRagRetriever" do
        allow(BookingRequests::VenueRagRetriever).to receive(:call)
        described_class.call(inbox_message: build_inbox_message)
        expect(BookingRequests::VenueRagRetriever).not_to have_received(:call)
      end
    end

    context "when a concurrent reconcile races to create the same pending_review draft" do
      it "returns draft_created: false rather than raising" do
        inbox_message = build_inbox_message

        # First reconcile creates the booking request and its draft
        described_class.call(inbox_message: inbox_message)

        # Simulate a concurrent reconcile: booking_request exists (extraction_locked path),
        # but generate_draft hits RecordNotUnique because the draft was just created
        allow(Draft).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique)

        # Re-reconcile should not raise and should report no draft was created
        expect {
          result = described_class.call(inbox_message: inbox_message)
          expect(result).to satisfy { |r| r.nil? || r.draft_created == false }
        }.not_to raise_error
      end
    end

    it "does not re-call LLM on RecordNotUnique retry" do
      call_count = 0
      allow_any_instance_of(BookingRequests::Classifier).to receive(:call_openai) do
        call_count += 1
        { "booking_request" => true }
      end

      attempts = 0
      original_save = BookingRequest.instance_method(:save!)
      allow_any_instance_of(BookingRequest).to receive(:save!) do |instance|
        attempts += 1
        raise ActiveRecord::RecordNotUnique if attempts == 1
        original_save.bind_call(instance)
      end

      described_class.call(inbox_message: build_inbox_message)

      expect(call_count).to eq(1)
    end
  end
end
