require "rails_helper"

RSpec.describe BookingRequests::Transition do
  let(:account) { create(:account) }
  let(:booking_request) { create(:booking_request, account: account, status: "pending") }

  describe ".call" do
    context "with a valid transition" do
      it "updates the booking request status" do
        described_class.call(booking_request: booking_request, to: "reviewing")
        expect(booking_request.reload.status).to eq("reviewing")
      end

      it "creates an EventLog entry" do
        expect {
          described_class.call(booking_request: booking_request, to: "reviewing")
        }.to change(EventLog, :count).by(1)

        log = EventLog.last
        expect(log.account).to eq(account)
        expect(log.event_type).to eq("booking_request.status_changed")
        expect(log.subject_type).to eq("BookingRequest")
        expect(log.subject_id).to eq(booking_request.id)
        expect(log.payload).to include("from" => "pending", "to" => "reviewing")
      end

      it "includes metadata in the EventLog payload" do
        described_class.call(
          booking_request: booking_request,
          to: "reviewing",
          metadata: { reason: "missing_fields" }
        )
        expect(EventLog.last.payload).to include("reason" => "missing_fields")
      end

      it "returns the booking request" do
        result = described_class.call(booking_request: booking_request, to: "reviewing")
        expect(result).to eq(booking_request)
      end
    end

    context "with all valid transitions" do
      it "allows pending → reviewing" do
        br = create(:booking_request, account: account, status: "pending")
        expect { described_class.call(booking_request: br, to: "reviewing") }.not_to raise_error
      end

      it "allows pending → confirmed" do
        br = create(:booking_request, account: account, status: "pending")
        expect { described_class.call(booking_request: br, to: "confirmed") }.not_to raise_error
      end

      it "allows pending → cancelled" do
        br = create(:booking_request, account: account, status: "pending")
        expect { described_class.call(booking_request: br, to: "cancelled") }.not_to raise_error
      end

      it "allows reviewing → pending" do
        br = create(:booking_request, account: account, status: "reviewing")
        expect { described_class.call(booking_request: br, to: "pending") }.not_to raise_error
      end

      it "allows reviewing → confirmed" do
        br = create(:booking_request, account: account, status: "reviewing")
        expect { described_class.call(booking_request: br, to: "confirmed") }.not_to raise_error
      end

      it "allows reviewing → rejected" do
        br = create(:booking_request, account: account, status: "reviewing")
        expect { described_class.call(booking_request: br, to: "rejected") }.not_to raise_error
      end

      it "allows reviewing → cancelled" do
        br = create(:booking_request, account: account, status: "reviewing")
        expect { described_class.call(booking_request: br, to: "cancelled") }.not_to raise_error
      end

      it "allows confirmed → cancelled" do
        br = create(:booking_request, account: account, status: "confirmed")
        expect { described_class.call(booking_request: br, to: "cancelled") }.not_to raise_error
      end

      it "allows rejected → cancelled" do
        br = create(:booking_request, account: account, status: "rejected")
        expect { described_class.call(booking_request: br, to: "cancelled") }.not_to raise_error
      end
    end

    context "with an invalid transition" do
      it "raises InvalidTransition for confirmed → pending" do
        br = create(:booking_request, account: account, status: "confirmed")
        expect {
          described_class.call(booking_request: br, to: "pending")
        }.to raise_error(BookingRequests::Transition::InvalidTransition)
      end

      it "raises InvalidTransition for cancelled → pending" do
        br = create(:booking_request, account: account, status: "cancelled")
        expect {
          described_class.call(booking_request: br, to: "pending")
        }.to raise_error(BookingRequests::Transition::InvalidTransition)
      end

      it "raises InvalidTransition for rejected → confirmed" do
        br = create(:booking_request, account: account, status: "rejected")
        expect {
          described_class.call(booking_request: br, to: "confirmed")
        }.to raise_error(BookingRequests::Transition::InvalidTransition)
      end

      it "does not update status on invalid transition" do
        br = create(:booking_request, account: account, status: "confirmed")
        begin
          described_class.call(booking_request: br, to: "pending")
        rescue BookingRequests::Transition::InvalidTransition
          nil
        end
        expect(br.reload.status).to eq("confirmed")
      end

      it "does not create an EventLog on invalid transition" do
        br = create(:booking_request, account: account, status: "cancelled")
        expect {
          begin
            described_class.call(booking_request: br, to: "reviewing")
          rescue BookingRequests::Transition::InvalidTransition
            nil
          end
        }.not_to change(EventLog, :count)
      end
    end
  end
end
