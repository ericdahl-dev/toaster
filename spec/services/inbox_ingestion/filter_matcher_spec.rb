# frozen_string_literal: true

require "rails_helper"

RSpec.describe InboxIngestion::FilterMatcher do
  let(:account) { create(:account) }
  let(:connection) { create(:imap_connection, account: account) }
  let(:venue_a) { create(:venue, account: account, name: "Grand Hall") }
  let(:venue_b) { create(:venue, account: account, name: "The Loft") }

  before do
    create(:inbox_filter, imap_connection: connection, venue: venue_a, keyword: "grand hall", position: 0)
    create(:inbox_filter, imap_connection: connection, venue: venue_b, keyword: "loft", position: 1)
  end

  subject(:matcher) { described_class.new(imap_connection: connection.reload) }

  it "returns the first matching venue (case-insensitive)" do
    expect(matcher.match(subject: "Inquiry for Grand Hall")).to eq(venue_a)
  end

  it "matches the second filter when first does not match" do
    expect(matcher.match(subject: "Booking enquiry - The Loft")).to eq(venue_b)
  end

  it "returns nil when no filter matches" do
    expect(matcher.match(subject: "General inquiry")).to be_nil
  end

  it "returns nil for blank subject" do
    expect(matcher.match(subject: "")).to be_nil
    expect(matcher.match(subject: nil)).to be_nil
  end

  it "respects insertion order (position)" do
    create(:inbox_filter, imap_connection: connection, venue: venue_b, keyword: "grand", position: 2)
    expect(matcher.match(subject: "grand hall event")).to eq(venue_a)
  end
end
