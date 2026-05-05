# frozen_string_literal: true

require "rails_helper"

RSpec.describe InboxSyncScheduler do
  describe ".schedule" do
    it "enqueues SyncImapJob for an ImapConnection" do
      connection = create(:imap_connection)
      expect { described_class.schedule(connection) }
        .to have_enqueued_job(SyncImapJob).with(connection.id)
    end

    it "enqueues SyncAgentMailboxJob for an AgentmailConnection" do
      connection = create(:agentmail_connection)
      expect { described_class.schedule(connection) }
        .to have_enqueued_job(SyncAgentMailboxJob).with(connection.id)
    end

    it "rejects unsupported connection types" do
      expect { described_class.schedule(Object.new) }
        .to raise_error(ArgumentError, /does not support Object/)
    end
  end
end
