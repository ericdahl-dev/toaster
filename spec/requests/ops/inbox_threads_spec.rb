# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Ops inbox threads", type: :request do
  around do |example|
    prev = ENV["OPS_AUTH_TOKEN"]
    ENV["OPS_AUTH_TOKEN"] = "secret-token"
    example.run
  ensure
    if prev.nil?
      ENV.delete("OPS_AUTH_TOKEN")
    else
      ENV["OPS_AUTH_TOKEN"] = prev
    end
  end

  def count_queries(&block)
    count = 0
    counter = ->(*, **) { count += 1 }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    count
  end

  describe "GET /ops/inbox_threads" do
    it "returns 401 when the token header is missing" do
      get "/ops/inbox_threads"

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).to include("error" => "Unauthorized")
    end

    it "returns one row when two inbound messages share a provider thread" do
      account = create(:account)
      create(
        :inbox_message,
        account: account,
        provider: "imap",
        provider_thread_id: "t-merge",
        provider_message_id: "m-a",
        subject: "Same thread",
        from_name: "Alex",
        from_email: "alex@example.com",
        received_at: 2.days.ago
      )
      create(
        :inbox_message,
        account: account,
        provider: "imap",
        provider_thread_id: "t-merge",
        provider_message_id: "m-b",
        subject: "Re: Same thread",
        from_name: "Alex",
        from_email: "alex@example.com",
        received_at: 1.day.ago
      )

      get "/ops/inbox_threads", headers: { "X-Ops-Token" => "secret-token" }

      expect(response).to have_http_status(:ok)
      threads = response.parsed_body.fetch("inbox_threads")
      expect(threads.length).to eq(1)
      expect(threads.first).to include(
        "account_id" => account.id,
        "provider" => "imap",
        "kind" => "thread",
        "provider_thread_id" => "t-merge",
        "anchor_inbox_message_id" => nil
      )
      expect(threads.first.fetch("last_activity_at")).to be_present
    end

    it "executes a bounded number of queries regardless of thread count" do
      account = create(:account)
      5.times do |i|
        create(
          :inbox_message,
          account: account,
          provider: "imap",
          provider_thread_id: "thread-#{i}",
          provider_message_id: "msg-#{i}",
          received_at: i.days.ago
        )
      end

      baseline_queries = count_queries do
        get "/ops/inbox_threads", headers: {"X-Ops-Token" => "secret-token"}
      end

      account2 = create(:account)
      10.times do |i|
        create(
          :inbox_message,
          account: account2,
          provider: "imap",
          provider_thread_id: "thread-#{i}",
          provider_message_id: "msg2-#{i}",
          received_at: i.days.ago
        )
      end

      scaled_queries = count_queries do
        get "/ops/inbox_threads", headers: {"X-Ops-Token" => "secret-token"}
      end

      expect(scaled_queries).to be <= baseline_queries + 2
    end
  end

  describe "GET /ops/inbox_threads/view" do
    it "returns a chronological timeline of inbox messages and drafts" do
      account = create(:account)
      contact = create(:contact, account: account)
      convo = create(:conversation_thread, account: account, contact: contact, provider_thread_id: "t-line")
      inbound = create(
        :inbox_message,
        account: account,
        provider: "imap",
        provider_thread_id: "t-line",
        provider_message_id: "in-1",
        direction: :inbound,
        received_at: 3.days.ago
      )
      create(
        :inbox_message,
        account: account,
        provider: "imap",
        provider_thread_id: "t-line",
        provider_message_id: "out-1",
        direction: :outbound,
        from_email: "venue@example.com",
        received_at: 2.days.ago
      )
      booking = create(
        :booking_request,
        account: account,
        contact: contact,
        conversation_thread: convo,
        source_inbox_message: inbound
      )
      create(
        :draft,
        account: account,
        booking_request: booking,
        status: :pending_review,
        body: "Draft reply",
        created_at: 1.day.ago
      )

      get "/ops/inbox_threads/view",
        params: { account_id: account.id, provider: "imap", provider_thread_id: "t-line" },
        headers: { "X-Ops-Token" => "secret-token" }

      expect(response).to have_http_status(:ok)
      body = response.parsed_body.fetch("inbox_thread")
      expect(body.fetch("kind")).to eq("thread")
      timeline = body.fetch("timeline")
      expect(timeline.length).to eq(3)
      sort_times = timeline.map { |i| Time.zone.parse(i.fetch("sort_at")) }
      expect(sort_times).to eq(sort_times.sort)
      expect(timeline.map { |i| i.fetch("type") }).to eq(%w[inbox_message inbox_message draft])
      draft_item = timeline.last
      expect(draft_item.fetch("type")).to eq("draft")
      expect(draft_item.fetch("default_collapsed")).to be(false)
      expect(body.dig("booking_request", "status")).to eq(booking.status)
    end

    it "marks rejected drafts as collapsed by default in the payload" do
      account = create(:account)
      contact = create(:contact, account: account)
      convo = create(:conversation_thread, account: account, contact: contact, provider_thread_id: "t-rej")
      inbound = create(
        :inbox_message,
        account: account,
        provider: "imap",
        provider_thread_id: "t-rej",
        provider_message_id: "in-rej",
        received_at: 1.day.ago
      )
      booking = create(
        :booking_request,
        account: account,
        contact: contact,
        conversation_thread: convo,
        source_inbox_message: inbound
      )
      create(:draft, account: account, booking_request: booking, status: :rejected, body: "Bad")

      get "/ops/inbox_threads/view",
        params: { account_id: account.id, provider: "imap", provider_thread_id: "t-rej" },
        headers: { "X-Ops-Token" => "secret-token" }

      expect(response).to have_http_status(:ok)
      draft_item = response.parsed_body.dig("inbox_thread", "timeline").find { |i| i["type"] == "draft" }
      expect(draft_item.fetch("default_collapsed")).to be(true)
    end

    it "returns 404 for an unknown thread" do
      account = create(:account)

      get "/ops/inbox_threads/view",
        params: { account_id: account.id, provider: "imap", provider_thread_id: "missing" },
        headers: { "X-Ops-Token" => "secret-token" }

      expect(response).to have_http_status(:not_found)
    end
  end
end
