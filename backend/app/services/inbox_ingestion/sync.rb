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

      adapter.each_normalized_message do |attrs|
        inbox_message, created = upsert(attrs)
        messages << inbox_message
        if created
          created_count += 1
        else
          deduped_count += 1
        end
      end

      adapter.write_checkpoint_after_batch(
        created_count: created_count,
        deduped_count: deduped_count,
        messages: messages
      )

      Result.new(created_count: created_count, deduped_count: deduped_count, messages: messages)
    end

    private

    attr_reader :adapter

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
