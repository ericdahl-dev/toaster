require "rails_helper"

RSpec.describe "Agent mailbox POC flow", type: :request do
  around do |example|
    prev = ENV["OPS_AUTH_TOKEN"]
    ENV["OPS_AUTH_TOKEN"] = "test-ops-token"
    example.run
  ensure
    if prev.nil?
      ENV.delete("OPS_AUTH_TOKEN")
    else
      ENV["OPS_AUTH_TOKEN"] = prev
    end
  end

  it "covers sync, duplicate delivery protection, extraction, and operator inspection" do
    account = create(:account)
    fetcher = instance_double(AgentMailbox::Fetcher)
    payload = {
      provider: "agent_mailbox",
      provider_message_id: "demo-msg-1",
      provider_thread_id: "demo-thread-1",
      direction: "inbound",
      from_email: "lead@example.com",
      from_name: "Demo Lead",
      to_emails: [ "agent@example.com" ],
      subject: "Wedding for 120 guests on June 14, 2026",
      body_text: "Hi, we're looking for a venue on June 14, 2026 for 120 guests with a budget of $15000.",
      received_at: Time.zone.parse("2026-04-01 10:00:00 UTC"),
      raw_payload: { "messageId" => "demo-msg-1", "threadId" => "demo-thread-1" }
    }

    allow(fetcher).to receive(:fetch_messages).and_return([ payload ])

    first_sync = AgentMailbox::Sync.call(account: account, fetcher: fetcher)
    second_sync = AgentMailbox::Sync.call(account: account, fetcher: fetcher)

    expect(first_sync.created_count).to eq(1)
    expect(second_sync.deduped_count).to eq(1)
    expect(account.inbox_messages.count).to eq(1)

    inbox_message = account.inbox_messages.first
    extraction = AgentMailbox::ExtractBookingRequest.call(inbox_message: inbox_message)

    expect(extraction.booking_request).to be_persisted
    expect(extraction.booking_request.headcount).to eq(120)
    expect(extraction.booking_request.event_date).to eq(Date.new(2026, 6, 14))
    expect(extraction.booking_request.budget_cents).to eq(1_500_000)

    get "/ops/inbox_messages", headers: { "X-Ops-Token" => "test-ops-token" }
    expect(response).to have_http_status(:ok)
    list_entry = response.parsed_body.fetch("inbox_messages").find { |item| item["id"] == inbox_message.id }
    expect(list_entry).to be_present
    expect(list_entry.fetch("booking_request")).to include(
      "id" => extraction.booking_request.id,
      "status" => "pending"
    )

    get "/ops/inbox_messages/#{inbox_message.id}", headers: { "X-Ops-Token" => "test-ops-token" }
    expect(response).to have_http_status(:ok)
    detail = response.parsed_body.fetch("inbox_message")
    expect(detail.fetch("booking_request")).to include(
      "headcount" => 120,
      "event_date" => "2026-06-14",
      "budget_cents" => 1_500_000,
      "missing_fields" => []
    )
  end
end
