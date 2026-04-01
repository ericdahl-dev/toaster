module AgentMailbox
  class Sync
    Result = Struct.new(:created_count, :deduped_count, :messages, keyword_init: true)

    def self.call(account:, fetcher: Fetcher.new)
      new(account: account, fetcher: fetcher).call
    end

    def initialize(account:, fetcher:)
      @account = account
      @fetcher = fetcher
    end

    def call
      created_count = 0
      deduped_count = 0
      messages = []

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

          if new_record
            created_count += 1
          else
            deduped_count += 1
          end
        rescue ActiveRecord::RecordNotUnique
          # Another worker created this inbox_message concurrently.
          inbox_message = InboxMessage.find_by(
            account: account,
            provider: attrs[:provider],
            provider_message_id: attrs[:provider_message_id]
          )

          # If for some reason the record still doesn't exist, re-raise.
          raise unless inbox_message

          inbox_message.assign_attributes(attrs.except(:provider_message_id, :provider))
          inbox_message.save!
          deduped_count += 1
        end

        messages << inbox_message
      end

      Result.new(created_count: created_count, deduped_count: deduped_count, messages: messages)
    end

    private

    attr_reader :account, :fetcher

    def normalize(payload)
      data = payload.deep_symbolize_keys

      {
        provider: data.fetch(:provider, "agent_mailbox"),
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
