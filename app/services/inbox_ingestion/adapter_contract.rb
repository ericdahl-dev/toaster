module InboxIngestion
  module AdapterContract
    REQUIRED = %i[account each_normalized_message write_checkpoint_after_batch resolve_venue after_message_reconciled].freeze

    def self.assert!(adapter)
      missing = REQUIRED.reject { |m| adapter.respond_to?(m) }
      return if missing.empty?

      raise ArgumentError, "InboxIngestion adapter missing: #{missing.join(", ")}"
    end
  end
end
