module Imap
  class Sync
    Result = Struct.new(:created_count, :deduped_count, :messages, keyword_init: true)

    def self.call(imap_connection:, fetcher: nil)
      fetcher ||= Fetcher.new(imap_connection: imap_connection)
      new(imap_connection: imap_connection, fetcher: fetcher).call
    end

    def initialize(imap_connection:, fetcher:)
      @imap_connection = imap_connection
      @fetcher = fetcher
    end

    def call
      created_count = 0
      deduped_count = 0
      messages = []
      max_uid = imap_connection.last_synced_uid

      fetcher.fetch_messages.each do |payload|
        inbox_message = persist_message(payload)
        messages << inbox_message

        if inbox_message.previously_new_record?
          created_count += 1
        else
          deduped_count += 1
        end

        uid = payload.dig(:raw_payload, "uid")&.to_i
        max_uid = uid if uid && (max_uid.nil? || uid > max_uid)
      end

      imap_connection.update!(last_synced_uid: max_uid) if max_uid != imap_connection.last_synced_uid

      Result.new(created_count: created_count, deduped_count: deduped_count, messages: messages)
    end

    private

    attr_reader :imap_connection, :fetcher

    def persist_message(payload)
      attrs = payload.deep_symbolize_keys
      account = imap_connection.account

      begin
        msg = InboxMessage.find_or_initialize_by(
          account: account,
          provider: attrs[:provider],
          provider_message_id: attrs[:provider_message_id]
        )
        new_record = msg.new_record?
        msg.assign_attributes(attrs.except(:provider, :provider_message_id))
        msg.save!
        msg.instance_variable_set(:@previously_new_record, new_record)
        msg
      rescue ActiveRecord::RecordNotUnique
        msg = InboxMessage.find_by!(
          account: account,
          provider: attrs[:provider],
          provider_message_id: attrs[:provider_message_id]
        )
        msg.instance_variable_set(:@previously_new_record, false)
        msg
      end
    end
  end
end
