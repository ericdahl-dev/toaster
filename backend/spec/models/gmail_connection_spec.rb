require "rails_helper"

RSpec.describe GmailConnection, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      account = create(:account)
      user = create(:user, account: account)
      expect(build(:gmail_connection, account: account, user: user)).to be_valid
    end

    it "is invalid without an email" do
      account = create(:account)
      user = create(:user, account: account)
      expect(build(:gmail_connection, account: account, user: user, email: nil)).not_to be_valid
    end

    it "is invalid with duplicate email within same account" do
      account = create(:account)
      user = create(:user, account: account)
      create(:gmail_connection, account: account, user: user, email: "test@gmail.com")
      user2 = create(:user, account: account)
      expect(build(:gmail_connection, account: account, user: user2, email: "test@gmail.com")).not_to be_valid
    end

    it "is invalid when user belongs to different account" do
      account1 = create(:account)
      account2 = create(:account)
      user = create(:user, account: account2)
      connection = build(:gmail_connection, account: account1, user: user)
      expect(connection).not_to be_valid
      expect(connection.errors[:user]).to include("must belong to the same account")
    end
  end

  describe "associations" do
    it "belongs to account" do
      connection = create(:gmail_connection)
      expect(connection.account).to be_a(Account)
    end

    it "belongs to user" do
      connection = create(:gmail_connection)
      expect(connection.user).to be_a(User)
    end
  end

  describe "scopes" do
    let(:account) { create(:account) }
    let(:user) { create(:user, account: account) }

    describe ".active_connections" do
      it "returns only active connections" do
        active = create(:gmail_connection, account: account, user: user, active: true)
        inactive = create(:gmail_connection, account: account, user: create(:user, account: account), active: false)
        expect(GmailConnection.active_connections).to include(active)
        expect(GmailConnection.active_connections).not_to include(inactive)
      end
    end

    describe ".expired_watch" do
      it "returns connections with no watch expiration" do
        no_watch = create(:gmail_connection, account: account, user: user, watch_expiration: nil)
        expect(GmailConnection.expired_watch).to include(no_watch)
      end

      it "returns connections with past watch expiration" do
        expired = create(:gmail_connection, account: account, user: user, watch_expiration: 1.hour.ago)
        expect(GmailConnection.expired_watch).to include(expired)
      end

      it "excludes connections with future watch expiration" do
        active_watch = create(:gmail_connection, account: account, user: user, watch_expiration: 1.hour.from_now)
        expect(GmailConnection.expired_watch).not_to include(active_watch)
      end
    end

    describe ".healthy" do
      it "returns active connections with a future watch expiration" do
        healthy = create(:gmail_connection, account: account, user: user, active: true, watch_expiration: 2.days.from_now)
        expect(GmailConnection.healthy).to include(healthy)
      end

      it "excludes inactive connections" do
        inactive = create(:gmail_connection, account: account, user: create(:user, account: account), active: false, watch_expiration: 2.days.from_now)
        expect(GmailConnection.healthy).not_to include(inactive)
      end

      it "excludes connections with expired watches" do
        expired_watch = create(:gmail_connection, account: account, user: user, active: true, watch_expiration: 1.hour.ago)
        expect(GmailConnection.healthy).not_to include(expired_watch)
      end
    end
  end

  describe "#token_expired?" do
    it "returns false when token_expires_at is nil" do
      connection = build(:gmail_connection, token_expires_at: nil)
      expect(connection.token_expired?).to be false
    end

    it "returns false when token_expires_at is in the future" do
      connection = build(:gmail_connection, token_expires_at: 1.hour.from_now)
      expect(connection.token_expired?).to be false
    end

    it "returns true when token_expires_at is in the past" do
      connection = build(:gmail_connection, token_expires_at: 1.hour.ago)
      expect(connection.token_expired?).to be true
    end
  end

  describe "#watch_active?" do
    it "returns false when watch_expiration is nil" do
      connection = build(:gmail_connection, watch_expiration: nil)
      expect(connection.watch_active?).to be false
    end

    it "returns false when watch_expiration is in the past" do
      connection = build(:gmail_connection, watch_expiration: 1.hour.ago)
      expect(connection.watch_active?).to be false
    end

    it "returns true when watch_expiration is in the future" do
      connection = build(:gmail_connection, watch_expiration: 1.hour.from_now)
      expect(connection.watch_active?).to be true
    end
  end

  describe "#watch_expired?" do
    it "returns true when watch_expiration is nil" do
      connection = build(:gmail_connection, watch_expiration: nil)
      expect(connection.watch_expired?).to be true
    end

    it "returns true when watch_expiration is in the past" do
      connection = build(:gmail_connection, watch_expiration: 1.hour.ago)
      expect(connection.watch_expired?).to be true
    end

    it "returns false when watch_expiration is in the future" do
      connection = build(:gmail_connection, watch_expiration: 1.hour.from_now)
      expect(connection.watch_expired?).to be false
    end
  end

  describe "#watch_expires_soon?" do
    it "returns false when watch is not active" do
      connection = build(:gmail_connection, watch_expiration: nil)
      expect(connection.watch_expires_soon?).to be false
    end

    it "returns true when watch expires within the renewal threshold" do
      connection = build(:gmail_connection, watch_expiration: 1.hour.from_now)
      expect(connection.watch_expires_soon?).to be true
    end

    it "returns false when watch expiration is beyond the renewal threshold" do
      connection = build(:gmail_connection, watch_expiration: 2.days.from_now)
      expect(connection.watch_expires_soon?).to be false
    end
  end

  describe "#healthy?" do
    it "returns true when active, token not expired, and watch active" do
      connection = build(:gmail_connection,
        active: true,
        token_expires_at: 1.hour.from_now,
        watch_expiration: 2.days.from_now
      )
      expect(connection.healthy?).to be true
    end

    it "returns false when inactive" do
      connection = build(:gmail_connection,
        active: false,
        token_expires_at: 1.hour.from_now,
        watch_expiration: 2.days.from_now
      )
      expect(connection.healthy?).to be false
    end

    it "returns false when token is expired" do
      connection = build(:gmail_connection,
        active: true,
        token_expires_at: 1.hour.ago,
        watch_expiration: 2.days.from_now
      )
      expect(connection.healthy?).to be false
    end

    it "returns false when watch is not active" do
      connection = build(:gmail_connection,
        active: true,
        token_expires_at: 1.hour.from_now,
        watch_expiration: nil
      )
      expect(connection.healthy?).to be false
    end
  end
end
