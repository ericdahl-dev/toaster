# frozen_string_literal: true

module InboxIngestion
  # Wraps Imap::Fetcher to import a bounded SINCE window (operator backfill).
  class SinceOverrideFetcher
    def initialize(fetcher, since:)
      @fetcher = fetcher
      @since = since
    end

    def fetch_messages
      @fetcher.fetch_messages(since: @since)
    end

    def mailbox_peak_uid
      @fetcher.mailbox_peak_uid
    end
  end
end
