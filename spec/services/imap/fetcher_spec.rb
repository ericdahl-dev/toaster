require "rails_helper"

RSpec.describe Imap::Fetcher do
  it "does not expose parse_address as an instance method (dead code deleted)" do
    fetcher = described_class.new(imap_connection: build(:imap_connection))
    expect(fetcher.class.private_method_defined?(:parse_address)).to be(false)
  end

  describe "#fetch_messages" do
    it "raises an error if host is blank" do
      connection = build(:imap_connection, host: "")
      fetcher = described_class.new(imap_connection: connection)
      expect { fetcher.fetch_messages }.to raise_error(Imap::Fetcher::Error, /host/)
    end

    it "raises an error if username is blank" do
      connection = build(:imap_connection, username: "")
      fetcher = described_class.new(imap_connection: connection)
      expect { fetcher.fetch_messages }.to raise_error(Imap::Fetcher::Error, /username/)
    end

    it "raises an error if password is blank" do
      connection = build(:imap_connection, password: "")
      fetcher = described_class.new(imap_connection: connection)
      expect { fetcher.fetch_messages }.to raise_error(Imap::Fetcher::Error, /password/)
    end

    context "with a stubbed IMAP connection" do
      let(:account) { create(:account) }
      let(:imap_connection) { create(:imap_connection, account: account) }
      let(:fetcher) { described_class.new(imap_connection: imap_connection) }
      let(:imap_double) { instance_double(Net::IMAP) }

      before do
        allow(Net::IMAP).to receive(:new).and_return(imap_double)
        allow(imap_double).to receive(:login)
        allow(imap_double).to receive(:select)
        allow(imap_double).to receive(:disconnect)
      end

      it "searches ALL when no last_synced_uid is set" do
        allow(imap_double).to receive(:uid_search).with([ "ALL" ]).and_return([])
        fetcher.fetch_messages
        expect(imap_double).to have_received(:uid_search).with([ "ALL" ])
      end

      it "searches by UID range when last_synced_uid is set" do
        imap_connection.update!(last_synced_uid: 42)
        allow(imap_double).to receive(:uid_search).with([ "UID", "43:*" ]).and_return([])
        fetcher.fetch_messages
        expect(imap_double).to have_received(:uid_search).with([ "UID", "43:*" ])
      end

      it "returns normalized messages for each fetched email" do
        raw_email = "From: Jamie Lead <jamie@example.com>\r\n" \
                    "To: agent@example.com\r\n" \
                    "Subject: Wedding inquiry\r\n" \
                    "Message-ID: <unique-id-123@example.com>\r\n" \
                    "Date: Tue, 01 Apr 2026 10:00:00 +0000\r\n" \
                    "Content-Type: text/plain; charset=UTF-8\r\n" \
                    "\r\n" \
                    "Looking for a venue for June 14, 2026.\r\n"

        mock_msg = instance_double("Net::IMAP::FetchData")
        allow(mock_msg).to receive(:attr).and_return(
          "UID" => 10,
          "RFC822" => raw_email,
          "ENVELOPE" => nil
        )

        allow(imap_double).to receive(:uid_search).and_return([ 10 ])
        allow(imap_double).to receive(:uid_fetch).with([ 10 ], Imap::Fetcher::FETCH_ATTRIBUTES).and_return([ mock_msg ])

        messages = fetcher.fetch_messages

        expect(messages.length).to eq(1)
        msg = messages.first
        expect(msg[:provider]).to eq("imap")
        expect(msg[:provider_message_id]).to eq("unique-id-123@example.com")
        expect(msg[:from_email]).to eq("jamie@example.com")
        expect(msg[:from_name]).to eq("Jamie Lead")
        expect(msg[:subject]).to eq("Wedding inquiry")
        expect(msg[:direction]).to eq("inbound")
        expect(msg[:body_text]).to include("venue")
      end

      it "returns an empty array when no messages are found" do
        allow(imap_double).to receive(:uid_search).and_return([])
        messages = fetcher.fetch_messages
        expect(messages).to be_empty
      end

      it "uses uid-based fallback provider_message_id when Message-ID header is absent" do
        raw_email = "From: sender@example.com\r\n" \
                    "To: agent@example.com\r\n" \
                    "Subject: No message id\r\n" \
                    "Date: Tue, 01 Apr 2026 10:00:00 +0000\r\n" \
                    "Content-Type: text/plain; charset=UTF-8\r\n" \
                    "\r\n" \
                    "Body text.\r\n"

        mock_msg = instance_double("Net::IMAP::FetchData")
        allow(mock_msg).to receive(:attr).and_return(
          "UID" => 99,
          "RFC822" => raw_email,
          "ENVELOPE" => nil
        )

        allow(imap_double).to receive(:uid_search).and_return([ 99 ])
        allow(imap_double).to receive(:uid_fetch).and_return([ mock_msg ])

        messages = fetcher.fetch_messages
        expect(messages.first[:provider_message_id]).to eq("uid:#{imap_connection.id}:99")
      end
    end
  end
end
