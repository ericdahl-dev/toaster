# frozen_string_literal: true

class ImapBackfillJob < ApplicationJob
  queue_as :default

  VALID_DAYS = [ 30, 90 ].freeze

  def perform(imap_connection_id, days)
    days = days.to_i
    raise ArgumentError, "invalid backfill days: #{days}" unless VALID_DAYS.include?(days)

    connection = ImapConnection.find(imap_connection_id)
    since = days.days.ago.to_date
    fetcher = Imap::Fetcher.new(imap_connection: connection)

    InboxIngestion::Sync.call(
      adapter: InboxIngestion::ImapAdapter.new(
        imap_connection: connection,
        fetcher: InboxIngestion::SinceOverrideFetcher.new(fetcher, since: since)
      )
    )

    connection.update!(last_backfill_at: Time.current, last_backfill_days: days)
  end
end
