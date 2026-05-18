require "rails_helper"

RSpec.describe BookingRequest, type: :model do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:thread) { create(:conversation_thread, account: account, contact: contact) }

  describe "validations" do
    it "is valid with valid attributes" do
      expect(build(:booking_request, account: account, contact: contact, conversation_thread: thread)).to be_valid
    end

    it "is invalid with unknown status" do
      expect {
        build(:booking_request, account: account, contact: contact, conversation_thread: thread, status: "unknown")
      }.to raise_error(ArgumentError)
    end

    it "is invalid with non-positive headcount" do
      expect(build(:booking_request, account: account, contact: contact, conversation_thread: thread, headcount: 0)).not_to be_valid
    end

    it "is valid with positive headcount" do
      expect(build(:booking_request, account: account, contact: contact, conversation_thread: thread, headcount: 10)).to be_valid
    end

    it "is invalid with negative budget" do
      expect(build(:booking_request, account: account, contact: contact, conversation_thread: thread, budget: -1)).not_to be_valid
    end

    it "is valid with zero budget" do
      expect(build(:booking_request, account: account, contact: contact, conversation_thread: thread, budget: 0)).to be_valid
    end

    it "is invalid when event_end_date is before event_date" do
      br = build(:booking_request,
        account: account, contact: contact, conversation_thread: thread,
        event_date: Date.today + 10,
        event_end_date: Date.today + 5)
      expect(br).not_to be_valid
      expect(br.errors[:event_end_date]).to include("must be on or after event_date")
    end

    it "is valid when event_end_date equals event_date" do
      date = Date.today + 10
      expect(build(:booking_request,
        account: account, contact: contact, conversation_thread: thread,
        event_date: date,
        event_end_date: date)).to be_valid
    end

    it "is invalid when contact belongs to different account" do
      other_contact = create(:contact, account: create(:account))
      br = build(:booking_request, account: account, contact: other_contact, conversation_thread: thread)
      expect(br).not_to be_valid
      expect(br.errors[:contact]).to include("must belong to the same account")
    end

    it "is invalid when conversation_thread belongs to different account" do
      other_account = create(:account)
      other_contact = create(:contact, account: other_account)
      other_thread = create(:conversation_thread, account: other_account, contact: other_contact)
      br = build(:booking_request, account: account, contact: contact, conversation_thread: other_thread)
      expect(br).not_to be_valid
      expect(br.errors[:conversation_thread]).to include("must belong to the same account")
    end

    it "is invalid when venue belongs to different account" do
      venue = create(:venue, account: create(:account))
      br = build(:booking_request, account: account, contact: contact, conversation_thread: thread, venue: venue)
      expect(br).not_to be_valid
      expect(br.errors[:venue]).to include("must belong to the same account")
    end
  end

  describe "enums" do
    it "has correct status values" do
      expect(BookingRequest.statuses).to eq({
        "pending" => "pending",
        "reviewing" => "reviewing",
        "confirmed" => "confirmed",
        "cancelled" => "cancelled"
      })
    end
  end

  describe "associations" do
    it "belongs to account" do
      br = create(:booking_request, account: account, contact: contact, conversation_thread: thread)
      expect(br.account).to eq(account)
    end

    it "has many drafts" do
      br = create(:booking_request, account: account, contact: contact, conversation_thread: thread)
      draft = create(:draft, account: account, booking_request: br)
      expect(br.drafts).to include(draft)
    end

    it "has many tasks" do
      br = create(:booking_request, account: account, contact: contact, conversation_thread: thread)
      task = create(:task, account: account, booking_request: br)
      expect(br.tasks).to include(task)
    end
  end

  describe "#first_received_at" do
    let(:br) { create(:booking_request, account: account, contact: contact, conversation_thread: thread) }

    it "uses source inbox message received_at when present" do
      received = Time.zone.parse("2023-08-09 14:30")
      inbox = create(:inbox_message, account: account, received_at: received)
      br.update!(source_inbox_message: inbox, created_at: Time.zone.parse("2026-05-18 10:00"))

      expect(br.first_received_at).to eq(received)
    end
  end

  describe "#last_activity" do
    let(:br) { create(:booking_request, account: account, contact: contact, conversation_thread: thread) }

    it "reports inbound when the latest message is from the contact" do
      br.update!(updated_at: Time.zone.parse("2026-05-17 09:00"))
      create(:message, account: account, conversation_thread: thread, booking_request: br,
        direction: :inbound, sent_at: Time.zone.parse("2026-05-18 15:00"))
      create(:draft, account: account, booking_request: br, status: :sent,
        created_at: Time.zone.parse("2026-05-18 10:00"))

      activity = br.last_activity

      expect(activity.at).to eq(Time.zone.parse("2026-05-18 15:00"))
      expect(activity.direction).to eq("inbound")
    end

    it "reports outbound when the latest venue draft is newer than inbound mail" do
      create(:message, account: account, conversation_thread: thread, booking_request: br,
        direction: :inbound, sent_at: Time.zone.parse("2026-05-18 10:00"))
      create(:draft, account: account, booking_request: br, status: :sent,
        created_at: Time.zone.parse("2026-05-18 16:00"))

      activity = br.last_activity

      expect(activity.at).to eq(Time.zone.parse("2026-05-18 16:00"))
      expect(activity.direction).to eq("outbound")
    end
  end

  describe "intake fields" do
    let(:br) { create(:booking_request, account: account, contact: contact, conversation_thread: thread) }

    it "stores booking_type free text" do
      br.update!(booking_type: "east room")
      expect(br.reload.booking_type).to eq("east room")
    end

    it "stores lead_recap free text" do
      br.update!(lead_recap: "Birthday party for 40 guests on a Saturday night")
      expect(br.reload.lead_recap).to eq("Birthday party for 40 guests on a Saturday night")
    end

    it "stores feature_preferences as array" do
      br.update!(feature_preferences: [ "karaoke", "private_bar" ])
      expect(br.reload.feature_preferences).to eq([ "karaoke", "private_bar" ])
    end

    it "accepts valid duration values" do
      %w[2_hours 2_5_hours 3_hours all_night].each do |val|
        br.duration = val
        expect(br).to be_valid
      end
    end

    it "rejects invalid duration values" do
      expect { br.duration = "forever" }.to raise_error(ArgumentError)
    end

    it "accepts valid private_space_preference values" do
      %w[private semi_private flexible not_sure].each do |val|
        br.private_space_preference = val
        expect(br).to be_valid
      end
    end

    it "rejects invalid private_space_preference values" do
      expect { br.private_space_preference = "secret" }.to raise_error(ArgumentError)
    end

    it "accepts valid beverage_format values" do
      %w[cash_bar hosted_tab drink_tickets timed_package].each do |val|
        br.beverage_format = val
        expect(br).to be_valid
      end
    end

    it "rejects invalid beverage_format values" do
      expect { br.beverage_format = "byo" }.to raise_error(ArgumentError)
    end

    it "belongs_to recommended_venue_space optionally" do
      space = create(:venue_space, venue: create(:venue, account: account))
      br.update!(recommended_venue_space: space)
      expect(br.reload.recommended_venue_space).to eq(space)
    end

    it "allows nil recommended_venue_space" do
      expect(br.recommended_venue_space).to be_nil
    end
  end
end
