require "rails_helper"

RSpec.describe ImapConnection, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      expect(build(:imap_connection)).to be_valid
    end

    it "is invalid without a host" do
      expect(build(:imap_connection, host: nil)).not_to be_valid
    end

    it "is invalid without a username" do
      expect(build(:imap_connection, username: nil)).not_to be_valid
    end

    it "is invalid without a port" do
      expect(build(:imap_connection, port: nil)).not_to be_valid
    end

    it "is invalid without an inbox_folder" do
      expect(build(:imap_connection, inbox_folder: nil)).not_to be_valid
    end

    it "is invalid with duplicate username+host within same account" do
      account = create(:account)
      create(:imap_connection, account: account, host: "imap.example.com", username: "user@example.com")
      expect(build(:imap_connection, account: account, host: "imap.example.com", username: "user@example.com")).not_to be_valid
    end

    it "allows the same username+host for a different account" do
      account1 = create(:account)
      account2 = create(:account)
      create(:imap_connection, account: account1, host: "imap.example.com", username: "user@example.com")
      expect(build(:imap_connection, account: account2, host: "imap.example.com", username: "user@example.com")).to be_valid
    end

    it "allows the same username on a different host within the same account" do
      account = create(:account)
      create(:imap_connection, account: account, host: "imap.example.com", username: "user@example.com")
      expect(build(:imap_connection, account: account, host: "imap.other.com", username: "user@example.com")).to be_valid
    end
  end

  describe "associations" do
    it "belongs to account" do
      connection = create(:imap_connection)
      expect(connection.account).to be_a(Account)
    end
  end

  describe "scopes" do
    it "active_connections returns only active connections" do
      account = create(:account)
      active = create(:imap_connection, account: account, active: true)
      inactive = create(:imap_connection, account: account, host: "imap.other.com", username: "other@example.com", active: false)

      results = ImapConnection.active_connections
      expect(results).to include(active)
      expect(results).not_to include(inactive)
    end
  end
end
