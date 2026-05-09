require "rails_helper"

RSpec.describe Imap::Session do
  let(:imap_connection) { build_stubbed(:imap_connection, host: "imap.example.com", port: 993, username: "user@example.com", password: "secret") }
  let(:imap_double) { instance_double(Net::IMAP) }

  before do
    allow(Net::IMAP).to receive(:new).and_return(imap_double)
    allow(imap_double).to receive(:login)
    allow(imap_double).to receive(:disconnect)
  end

  it "opens a connection, yields the imap object, and disconnects" do
    expect(Net::IMAP).to receive(:new).with("imap.example.com", port: 993, ssl: anything)
    expect(imap_double).to receive(:login).with("user@example.com", "secret")
    expect(imap_double).to receive(:disconnect)

    yielded = nil
    described_class.call(imap_connection: imap_connection) { |imap| yielded = imap }

    expect(yielded).to eq(imap_double)
  end

  it "disconnects even when the block raises" do
    expect(imap_double).to receive(:disconnect)

    expect {
      described_class.call(imap_connection: imap_connection) { raise "boom" }
    }.to raise_error("boom")
  end

  it "tolerates disconnect errors on cleanup" do
    allow(imap_double).to receive(:disconnect).and_raise(IOError)

    expect {
      described_class.call(imap_connection: imap_connection) { |_imap| }
    }.not_to raise_error
  end
end
