# frozen_string_literal: true

# Idempotent demo inbox + booking pipeline data for local development.
# Loaded from db/seeds.rb when Rails.env.development?
class DevelopmentDemoSeeds
  PROVIDER = "seed"

  def self.run(account: nil)
    new(account: account).run
  end

  def initialize(account: nil)
    @account = account
  end

  def run
    seed_venues
    seed_thread_cold_lead
    seed_thread_pending
    seed_thread_reviewing_missing
    seed_thread_with_draft
    seed_thread_confirmed
    seed_thread_rejected
    seed_thread_cancelled
    seed_thread_multi_message
    seed_thread_with_task
  end

  private

  def account
    @account || Account.find(1)
  end

  def seed_venues
    [
      {name: "Riverside Hall", address: "100 River Rd", capacity: 220},
      {name: "Skyline Rooftop", address: "55 High St, 12th floor", capacity: 80}
    ].each do |attrs|
      venue = Venue.find_or_initialize_by(account: account, name: attrs[:name])
      venue.assign_attributes(attrs.except(:name))
      venue.save!
    end
  end

  def seed_thread_cold_lead
    contact = upsert_contact(
      email: "alex.chen@example.com",
      name: "Alex Chen",
      phone: "555-0101"
    )
    thread = upsert_thread(
      contact: contact,
      provider_thread_id: "#{PROVIDER}:thread:cold-lead",
      subject: "Quick question about availability"
    )
    upsert_inbox(
      contact: contact,
      provider_thread_id: thread.provider_thread_id,
      provider_message_id: "#{PROVIDER}:inbox:cold-lead-1",
      subject: thread.subject,
      body_text: "Hi — do you host corporate mixers in Q3? Not sure of dates yet.",
      received_at: 2.hours.ago
    )
  end

  def seed_thread_pending
    contact = upsert_contact(
      email: "jamie.ortiz@example.com",
      name: "Jamie Ortiz",
      phone: "555-0102"
    )
    thread = upsert_thread(
      contact: contact,
      provider_thread_id: "#{PROVIDER}:thread:pending",
      subject: "June offsite — 40 people"
    )
    inbox = upsert_inbox(
      contact: contact,
      provider_thread_id: thread.provider_thread_id,
      provider_message_id: "#{PROVIDER}:inbox:pending-1",
      subject: thread.subject,
      body_text: "We need a full-day offsite June 18 for ~40 guests. Catering TBD.",
      received_at: 1.day.ago
    )
    upsert_booking_request(
      inbox: inbox,
      thread: thread,
      contact: contact,
      status: :pending,
      event_date: Date.current + 45,
      headcount: 40,
      budget_cents: 12_000_00,
      notes: "Ask about AV package.",
      missing_fields: [],
      review_reasons: [],
      extraction_snapshot: {"venue_type" => "offsite", "dates_mentioned" => ["June 18"]}
    )
  end

  def seed_thread_reviewing_missing
    contact = upsert_contact(
      email: "sam.rivera@example.com",
      name: "Sam Rivera",
      phone: "555-0103"
    )
    thread = upsert_thread(
      contact: contact,
      provider_thread_id: "#{PROVIDER}:thread:reviewing-missing",
      subject: "Wedding reception inquiry"
    )
    inbox = upsert_inbox(
      contact: contact,
      provider_thread_id: thread.provider_thread_id,
      provider_message_id: "#{PROVIDER}:inbox:reviewing-missing-1",
      subject: thread.subject,
      body_text: "We're planning a reception sometime in the fall. Budget flexible.",
      received_at: 2.days.ago
    )
    upsert_booking_request(
      inbox: inbox,
      thread: thread,
      contact: contact,
      status: :reviewing,
      event_date: nil,
      headcount: nil,
      budget_cents: nil,
      notes: nil,
      missing_fields: %w[event_date headcount],
      review_reasons: ["Seasonal window too wide"],
      extraction_snapshot: {}
    )
  end

  def seed_thread_with_draft
    contact = upsert_contact(
      email: "taylor.brooks@example.com",
      name: "Taylor Brooks",
      phone: "555-0104"
    )
    thread = upsert_thread(
      contact: contact,
      provider_thread_id: "#{PROVIDER}:thread:draft",
      subject: "Product launch dinner — July"
    )
    inbox = upsert_inbox(
      contact: contact,
      provider_thread_id: thread.provider_thread_id,
      provider_message_id: "#{PROVIDER}:inbox:draft-1",
      subject: thread.subject,
      body_text: "Launch dinner July 9 for 24 people. Need vegetarian options.",
      received_at: 3.days.ago
    )
    br = upsert_booking_request(
      inbox: inbox,
      thread: thread,
      contact: contact,
      status: :reviewing,
      event_date: Date.current + 65,
      headcount: 24,
      budget_cents: 4_500_00,
      notes: nil,
      missing_fields: [],
      review_reasons: [],
      extraction_snapshot: {"dietary" => "vegetarian options"}
    )
    upsert_pending_draft(booking_request: br, body: <<~TEXT.strip)
      Hi Taylor — thanks for the note. We can host July 9 for 24 with a vegetarian-forward menu.
      Proposed start: 6:30pm. Want me to hold the date for 48 hours?
    TEXT
  end

  def seed_thread_confirmed
    contact = upsert_contact(
      email: "riley.nguyen@example.com",
      name: "Riley Nguyen",
      phone: "555-0105"
    )
    thread = upsert_thread(
      contact: contact,
      provider_thread_id: "#{PROVIDER}:thread:confirmed",
      subject: "Confirmed: team celebration"
    )
    inbox = upsert_inbox(
      contact: contact,
      provider_thread_id: thread.provider_thread_id,
      provider_message_id: "#{PROVIDER}:inbox:confirmed-1",
      subject: thread.subject,
      body_text: "Let's lock Aug 2 for 60 guests. Thanks!",
      received_at: 4.days.ago
    )
    venue = Venue.find_by!(account: account, name: "Riverside Hall")
    upsert_booking_request(
      inbox: inbox,
      thread: thread,
      contact: contact,
      status: :confirmed,
      event_date: Date.current + 90,
      headcount: 60,
      budget_cents: 18_000_00,
      notes: "Deposit received.",
      venue: venue,
      missing_fields: [],
      review_reasons: [],
      extraction_snapshot: {"confirmed" => true}
    )
  end

  def seed_thread_rejected
    contact = upsert_contact(
      email: "casey.morales@example.com",
      name: "Casey Morales",
      phone: "555-0106"
    )
    thread = upsert_thread(
      contact: contact,
      provider_thread_id: "#{PROVIDER}:thread:rejected",
      subject: "NYE party — 300 guests"
    )
    inbox = upsert_inbox(
      contact: contact,
      provider_thread_id: thread.provider_thread_id,
      provider_message_id: "#{PROVIDER}:inbox:rejected-1",
      subject: thread.subject,
      body_text: "Need space for 300 on New Year's Eve.",
      received_at: 5.days.ago
    )
    upsert_booking_request(
      inbox: inbox,
      thread: thread,
      contact: contact,
      status: :rejected,
      event_date: Date.new(Date.current.year, 12, 31),
      headcount: 300,
      budget_cents: nil,
      notes: "Over capacity for venues list.",
      missing_fields: [],
      review_reasons: ["Exceeds venue capacity"],
      extraction_snapshot: {}
    )
  end

  def seed_thread_cancelled
    contact = upsert_contact(
      email: "morgan.lee@example.com",
      name: "Morgan Lee",
      phone: "555-0107"
    )
    thread = upsert_thread(
      contact: contact,
      provider_thread_id: "#{PROVIDER}:thread:cancelled",
      subject: "Workshop — May (cancelled)"
    )
    inbox = upsert_inbox(
      contact: contact,
      provider_thread_id: thread.provider_thread_id,
      provider_message_id: "#{PROVIDER}:inbox:cancelled-1",
      subject: thread.subject,
      body_text: "We need to cancel the May workshop — internal reschedule.",
      received_at: 6.days.ago
    )
    upsert_booking_request(
      inbox: inbox,
      thread: thread,
      contact: contact,
      status: :cancelled,
      event_date: Date.current + 20,
      headcount: 15,
      budget_cents: 2_000_00,
      notes: "Client cancelled.",
      missing_fields: [],
      review_reasons: [],
      extraction_snapshot: {}
    )
  end

  def seed_thread_multi_message
    contact = upsert_contact(
      email: "drew.patel@example.com",
      name: "Drew Patel",
      phone: "555-0108"
    )
    thread = upsert_thread(
      contact: contact,
      provider_thread_id: "#{PROVIDER}:thread:multi",
      subject: "Board dinner follow-up"
    )
    inbox_first = upsert_inbox(
      contact: contact,
      provider_thread_id: thread.provider_thread_id,
      provider_message_id: "#{PROVIDER}:inbox:multi-1",
      subject: thread.subject,
      body_text: "Can we do a board dinner on Sept 12 for 12 people?",
      received_at: 7.days.ago
    )
    upsert_booking_request(
      inbox: inbox_first,
      thread: thread,
      contact: contact,
      status: :pending,
      event_date: Date.current + 120,
      headcount: 12,
      budget_cents: 5_000_00,
      notes: nil,
      missing_fields: [],
      review_reasons: [],
      extraction_snapshot: {}
    )
    upsert_inbox(
      contact: contact,
      provider_thread_id: thread.provider_thread_id,
      provider_message_id: "#{PROVIDER}:inbox:multi-2",
      subject: "Re: Board dinner follow-up",
      body_text: "Also — one guest is gluten-free. Thanks!",
      received_at: 6.days.ago + 3.hours
    )
  end

  def seed_thread_with_task
    contact = upsert_contact(
      email: "jordan.kim@example.com",
      name: "Jordan Kim",
      phone: "555-0109"
    )
    thread = upsert_thread(
      contact: contact,
      provider_thread_id: "#{PROVIDER}:thread:with-task",
      subject: "Investor brunch"
    )
    inbox = upsert_inbox(
      contact: contact,
      provider_thread_id: thread.provider_thread_id,
      provider_message_id: "#{PROVIDER}:inbox:task-1",
      subject: thread.subject,
      body_text: "Brunch Oct 3 for 30 — need quote by Friday.",
      received_at: 8.days.ago
    )
    br = upsert_booking_request(
      inbox: inbox,
      thread: thread,
      contact: contact,
      status: :pending,
      event_date: Date.current + 150,
      headcount: 30,
      budget_cents: 7_500_00,
      notes: nil,
      missing_fields: [],
      review_reasons: [],
      extraction_snapshot: {}
    )
    task = Task.find_or_initialize_by(
      account: account,
      booking_request: br,
      title: "Send catering quote to Jordan"
    )
    task.assign_attributes(status: :open, due_at: 3.days.from_now)
    task.save!
  end

  def upsert_contact(email:, name:, phone: nil)
    Contact.find_or_initialize_by(account: account, email: email.downcase).tap do |c|
      c.assign_attributes(name: name, phone: phone)
      c.save!
    end
  end

  def upsert_thread(contact:, provider_thread_id:, subject:)
    ConversationThread.find_or_initialize_by(account: account, provider_thread_id: provider_thread_id).tap do |t|
      t.assign_attributes(contact: contact, subject: subject)
      t.save!
    end
  end

  def upsert_inbox(contact:, provider_thread_id:, provider_message_id:, subject:, body_text:, received_at:)
    InboxMessage.find_or_initialize_by(
      account: account,
      provider: PROVIDER,
      provider_message_id: provider_message_id
    ).tap do |m|
      m.assign_attributes(
        provider_thread_id: provider_thread_id,
        direction: :inbound,
        from_name: contact.name,
        from_email: contact.email,
        to_emails: ["events@toaster.local"],
        subject: subject,
        body_text: body_text,
        body_html: "<p>#{ERB::Util.html_escape(body_text)}</p>",
        received_at: received_at,
        raw_payload: {"seed" => true, "provider_message_id" => provider_message_id}
      )
      m.save!
    end
  end

  def upsert_booking_request(inbox:, thread:, contact:, status:, event_date:, headcount:, budget_cents:, notes:,
    missing_fields:, review_reasons:, extraction_snapshot:, venue: nil)
    BookingRequest.find_or_initialize_by(account: account, source_inbox_message_id: inbox.id).tap do |br|
      br.assign_attributes(
        conversation_thread: thread,
        contact: contact,
        venue: venue,
        status: status,
        event_date: event_date,
        event_end_date: nil,
        headcount: headcount,
        budget_cents: budget_cents,
        notes: notes,
        missing_fields: missing_fields,
        review_reasons: review_reasons,
        extraction_snapshot: extraction_snapshot
      )
      br.save!
    end
  end

  def upsert_pending_draft(booking_request:, body:)
    draft = booking_request.drafts.find_by(status: :pending_review)
    draft ||= booking_request.drafts.build(account: account, status: :pending_review)
    draft.assign_attributes(body: body)
    draft.save!
  end
end
