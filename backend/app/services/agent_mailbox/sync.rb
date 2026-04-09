module AgentMailbox
  class Sync
    Result = Struct.new(:created_count, :deduped_count, :messages, keyword_init: true)

    def self.call(connection:, fetcher: nil)
      fetcher ||= Fetcher.new(connection: connection)
      new(connection: connection, fetcher: fetcher).call
    end

    def initialize(connection:, fetcher:)
      @connection = connection
      @fetcher = fetcher
    end

    def call
      created_count = 0
      deduped_count = 0
      messages = []
      synced_at = Time.current

      fetcher.fetch_messages.each do |payload|
        attrs = normalize(payload)

        begin
          inbox_message = InboxMessage.find_or_initialize_by(
            account: account,
            provider: attrs[:provider],
            provider_message_id: attrs[:provider_message_id]
          )
          new_record = inbox_message.new_record?

          inbox_message.assign_attributes(attrs.except(:provider_message_id, :provider))
          inbox_message.save!

          new_record ? (created_count += 1) : (deduped_count += 1)
        rescue ActiveRecord::RecordNotUnique
          inbox_message = InboxMessage.find_by(
            account: account,
            provider: attrs[:provider],
            provider_message_id: attrs[:provider_message_id]
          )
          raise unless inbox_message

          inbox_message.assign_attributes(attrs.except(:provider_message_id, :provider))
          inbox_message.save!
          deduped_count += 1
        end

        messages << inbox_message
      end

      connection.update!(last_synced_at: synced_at)
      Result.new(created_count: created_count, deduped_count: deduped_count, messages: messages)
    end

    private

    attr_reader :connection, :fetcher

    def account
      connection.account
    end

    def normalize(payload)
      data = payload.deep_symbolize_keys

      {
        provider: data.fetch(:provider, "agentmail"),
        provider_message_id: data.fetch(:provider_message_id),
        provider_thread_id: data[:provider_thread_id],
        direction: data.fetch(:direction, "inbound"),
        from_email: data[:from_email],
        from_name: data[:from_name],
        to_emails: Array(data[:to_emails]),
        subject: data[:subject],
        body_text: data[:body_text],
        body_html: data[:body_html],
        received_at: data[:received_at],
        raw_payload: data.fetch(:raw_payload, payload)
      }
    end
  end
end
