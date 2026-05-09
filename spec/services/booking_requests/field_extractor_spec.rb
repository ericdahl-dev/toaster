require "rails_helper"

RSpec.describe BookingRequests::FieldExtractor do
  def call(subject: "", body_text: "")
    described_class.call(subject: subject, body_text: body_text)
  end

  it "extracts event date from body" do
    result = call(body_text: "We'd like to book for June 14, 2025.")
    expect(result[:event_date]).to eq(Date.new(2025, 6, 14))
  end

  it "extracts headcount from body" do
    result = call(body_text: "We'll have 80 guests attending.")
    expect(result[:headcount]).to eq(80)
  end

  it "extracts budget from body" do
    result = call(body_text: "Our budget is $5,000.")
    expect(result[:budget_cents]).to eq(500_000)
  end

  it "extracts fields from subject line" do
    result = call(subject: "Inquiry for March 22, 2026 – 50 guests – $2000")
    expect(result[:event_date]).to eq(Date.new(2026, 3, 22))
    expect(result[:headcount]).to eq(50)
    expect(result[:budget_cents]).to eq(200_000)
  end

  it "records missing fields when none found" do
    result = call(body_text: "Hi, interested in booking your venue.")
    expect(result[:missing_fields]).to contain_exactly("event_date", "headcount", "budget_cents")
  end

  it "status is reviewing when fields missing" do
    result = call(body_text: "No details here.")
    expect(result[:status]).to eq("reviewing")
  end

  it "status is pending when all fields present and unambiguous" do
    result = call(body_text: "June 14, 2025. 80 guests. $5,000.")
    expect(result[:status]).to eq("pending")
  end

  it "marks ambiguous event date as review reason" do
    result = call(body_text: "Either June 14, 2025 or July 20, 2025. 80 guests. $5,000.")
    expect(result[:review_reasons]).to include("ambiguous_event_date")
    expect(result[:event_date]).to be_nil
  end

  it "marks ambiguous headcount as review reason" do
    result = call(body_text: "June 14, 2025. Either 50 guests or 80 guests. $5,000.")
    expect(result[:review_reasons]).to include("ambiguous_headcount")
    expect(result[:headcount]).to be_nil
  end

  it "marks ambiguous budget as review reason" do
    result = call(body_text: "June 14, 2025. 80 guests. Budget $2,000 or $5,000.")
    expect(result[:review_reasons]).to include("ambiguous_budget_cents")
    expect(result[:budget_cents]).to be_nil
  end

  it "includes snapshot with iso8601 date" do
    result = call(body_text: "June 14, 2025. 80 guests. $5,000.")
    expect(result[:snapshot]).to eq(
      "event_date" => "2025-06-14",
      "headcount" => 80,
      "budget_cents" => 500_000
    )
  end

  it "does not use FactoryBot or database" do
    expect(BookingRequest).not_to receive(:new)
    call(body_text: "plain text with no DB")
  end
end
