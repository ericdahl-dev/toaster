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
    seed_thread_singleton_nil
  end

  private

  def account
    @account || Account.find(1)
  end

  def seed_venues
    [
      { name: "Riverside Hall", address: "100 River Rd", capacity: 220 },
      { name: "Skyline Rooftop", address: "55 High St, 12th floor", capacity: 80 }
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









  def seed_thread_singleton_nil
    contact = upsert_contact(
      email: "casey.singleton@example.com",
      name: "Casey Singleton",
      phone: "555-0111"
    )
    upsert_inbox_singleton_no_thread(
      contact: contact,
      provider_message_id: "#{PROVIDER}:inbox:singleton-nil-1",
      subject: "One-off question (no thread id)",
      body_text: "Inbox row with provider_thread_id nil for operator inbox singleton grouping.",
      received_at: 9.days.ago
    )
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


  def upsert_inbox_singleton_no_thread(contact:, provider_message_id:, subject:, body_text:, received_at:)
    InboxMessage.find_or_initialize_by(
      account: account,
      provider: PROVIDER,
      provider_message_id: provider_message_id
    ).tap do |m|
      m.assign_attributes(
        provider_thread_id: nil,
        direction: :inbound,
        from_name: contact.name,
        from_email: contact.email,
        to_emails: [ "events@toaster.local" ],
        subject: subject,
        body_text: body_text,
        body_html: "<p>#{ERB::Util.html_escape(body_text)}</p>",
        received_at: received_at,
        raw_payload: { "seed" => true, "singleton" => true }
      )
      m.save!
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
        to_emails: [ "events@toaster.local" ],
        subject: subject,
        body_text: body_text,
        body_html: "<p>#{ERB::Util.html_escape(body_text)}</p>",
        received_at: received_at,
        raw_payload: { "seed" => true, "provider_message_id" => provider_message_id }
      )
      m.save!
    end
  end
end
