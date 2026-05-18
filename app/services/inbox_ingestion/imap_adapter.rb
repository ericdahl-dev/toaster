module InboxIngestion
  class ImapAdapter
    def initialize(imap_connection:, fetcher: nil)
      @imap_connection = imap_connection
      @fetcher = fetcher || Imap::Fetcher.new(imap_connection: imap_connection)
      @max_uid = imap_connection.last_synced_uid
    end

    def account
      @imap_connection.account
    end

    def imap_connection
      @imap_connection
    end

    def each_normalized_message
      @fetcher.fetch_messages.each do |payload|
        uid = payload.dig(:raw_payload, "uid")&.to_i
        @max_uid = uid if uid && (@max_uid.nil? || uid > @max_uid)
        yield payload
      end
    end

    def write_checkpoint_after_batch(**)
      @imap_connection.reload
      advance_initial_checkpoint_if_needed

      return if @max_uid.nil?
      return if @max_uid == @imap_connection.last_synced_uid

      @imap_connection.update!(last_synced_uid: @max_uid)
    end

    def mark_seen(uids)
      return if uids.blank?

      Imap::Session.call(imap_connection: @imap_connection) do |imap|
        imap.select(@imap_connection.inbox_folder)
        imap.uid_store(uids, "+FLAGS", [ :Seen ])
      end
    end

    def advance_initial_checkpoint_if_needed
      return if @imap_connection.last_synced_uid.present?
      return if @max_uid.present?

      peak = @fetcher.mailbox_peak_uid
      @max_uid = peak if peak.present?
    end
  end
end
