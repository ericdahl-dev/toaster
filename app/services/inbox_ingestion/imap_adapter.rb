module InboxIngestion
  class ImapAdapter
    def initialize(imap_connection:, fetcher: nil)
      @imap_connection = imap_connection
      @fetcher = fetcher || Imap::Fetcher.new(imap_connection: imap_connection)
      @max_uid = imap_connection.last_synced_uid
      @uids_to_mark_seen = []
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

    def resolve_venue(attrs)
      subject = attrs[:subject] || attrs["subject"]
      InboxIngestion::FilterMatcher
        .new(imap_connection: imap_connection)
        .match(subject: subject)
    end

    def after_message_reconciled(attrs, reconcile_result)
      return unless reconcile_result&.draft_created

      raw = attrs[:raw_payload] || attrs["raw_payload"] || {}
      uid = raw[:uid] || raw["uid"]
      @uids_to_mark_seen << uid.to_i if uid
    end

    def write_checkpoint_after_batch(**)
      @imap_connection.reload
      advance_initial_checkpoint_if_needed

      if @max_uid.present? && @max_uid != @imap_connection.last_synced_uid
        @imap_connection.update!(last_synced_uid: @max_uid)
      end

      mark_seen(@uids_to_mark_seen) if @uids_to_mark_seen.any?
      @uids_to_mark_seen.clear
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
