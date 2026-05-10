module InboxIngestion
  class Sync
    Result = Struct.new(:created_count, :deduped_count, :messages, keyword_init: true)

    def self.call(adapter:)
      InboxIngestion::AdapterContract.assert!(adapter)
      new(adapter).call
    end

    def initialize(adapter)
      @adapter = adapter
    end

    def call
      created_count = 0
      deduped_count = 0
      messages = []
      uids_to_mark_seen = []

      adapter.each_normalized_message do |attrs|
        inbox_message, created = upsert(attrs)
        venue = resolve_venue(attrs)
        # See docs/adr/0001-post-ingestion-booking-reconcile.md
        reconcile_result = BookingRequests::Reconcile.call(inbox_message: inbox_message, venue: venue)
        messages << inbox_message
        if created
          created_count += 1
        else
          deduped_count += 1
        end

        if reconcile_result&.draft_created
          uid = attrs.dig(:raw_payload, "uid") || attrs.dig("raw_payload", "uid")
          uids_to_mark_seen << uid.to_i if uid
        end
      end

      adapter.write_checkpoint_after_batch(
        created_count: created_count,
        deduped_count: deduped_count,
        messages: messages
      )

      adapter.mark_seen(uids_to_mark_seen) if uids_to_mark_seen.any? && adapter.respond_to?(:mark_seen)

      Result.new(created_count: created_count, deduped_count: deduped_count, messages: messages)
    end

    private

    attr_reader :adapter

    def resolve_venue(attrs)
      return nil unless adapter.respond_to?(:imap_connection)

      InboxIngestion::FilterMatcher
        .new(imap_connection: adapter.imap_connection)
        .match(subject: attrs[:subject])
    end

    def upsert(attrs)
      attrs = attrs.deep_symbolize_keys
      account = adapter.account

      begin
        msg = InboxMessage.find_or_initialize_by(
          account: account,
          provider: attrs[:provider],
          provider_message_id: attrs[:provider_message_id]
        )
        created = msg.new_record?
        msg.assign_attributes(attrs.except(:provider, :provider_message_id))
        msg.save!
        [ msg, created ]
      rescue ActiveRecord::RecordNotUnique
        msg = InboxMessage.find_by!(
          account: account,
          provider: attrs[:provider],
          provider_message_id: attrs[:provider_message_id]
        )
        msg.assign_attributes(attrs.except(:provider, :provider_message_id))
        msg.save!
        [ msg, false ]
      end
    end
  end
end
