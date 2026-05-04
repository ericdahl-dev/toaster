module InboxIngestion
  class AgentMailboxAdapter
    def initialize(connection: nil, account: nil, fetcher: nil)
      @connection = connection
      @account = account || connection&.account
      raise ArgumentError, "connection or account required" unless @account

      @fetcher = fetcher || begin
        raise ArgumentError, "fetcher required when connection is nil" unless connection

        AgentMailbox::Fetcher.new(connection: connection)
      end
      @sync_started_at = Time.current
    end

    def account
      @account
    end

    def each_normalized_message
      @fetcher.fetch_messages.each { |payload| yield normalize(payload) }
    end

    def write_checkpoint_after_batch(**)
      @connection&.update!(last_synced_at: @sync_started_at)
    end

    private

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
