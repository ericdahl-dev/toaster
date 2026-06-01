# frozen_string_literal: true

module Toaster
  class LocalEmailTester
    class Error < StandardError; end

    Result = Struct.new(
      :connection,
      :subject,
      :from_email,
      :matched_uids,
      :response_uids,
      keyword_init: true
    )

    def self.call(...)
      new(...).call
    end

    def initialize(from_email:, from_name: "Test Customer", subject: nil, body: nil, account_id: nil, connection_id: nil, timeout_seconds: 60, poll_interval_seconds: 5, wait_for_response: false, customer_imap_host: nil, customer_imap_port: 993, customer_imap_ssl: true, customer_imap_username: nil, customer_imap_password: nil, customer_imap_inbox_folder: "INBOX")
      @from_email = from_email
      @from_name = from_name
      @subject = subject.presence || "Toaster local email test #{Time.current.iso8601}"
      @body = body.presence || "Hello from local toaster test at #{Time.current.iso8601}"
      @account_id = account_id
      @connection_id = connection_id
      @timeout_seconds = timeout_seconds.to_i
      @poll_interval_seconds = poll_interval_seconds.to_i
      @wait_for_response = wait_for_response
      @customer_imap_host = customer_imap_host
      @customer_imap_port = customer_imap_port.to_i
      @customer_imap_ssl = customer_imap_ssl
      @customer_imap_username = customer_imap_username
      @customer_imap_password = customer_imap_password
      @customer_imap_inbox_folder = customer_imap_inbox_folder
    end

    def call
      validate_timing!
      connection = resolve_connection!
      deliver_via_resend!(connection)
      matched_uids = wait_for_imap_receipt!(connection)
      response_uids = wait_for_customer_response?(connection) ? wait_for_customer_response!(connection) : []

      Result.new(
        connection: connection,
        subject: subject,
        from_email: from_email,
        matched_uids: matched_uids,
        response_uids: response_uids
      )
    end

    private

    attr_reader :from_email, :from_name, :subject, :body, :account_id, :connection_id, :timeout_seconds, :poll_interval_seconds,
      :wait_for_response, :customer_imap_host, :customer_imap_port, :customer_imap_ssl, :customer_imap_username,
      :customer_imap_password, :customer_imap_inbox_folder

    def validate_timing!
      raise Error, "timeout_seconds must be > 0" unless timeout_seconds.positive?
      raise Error, "poll_interval_seconds must be > 0" unless poll_interval_seconds.positive?
      raise Error, "customer_imap_port must be > 0" unless customer_imap_port.positive?
      raise Error, "Customer IMAP host/username/password are required when waiting for Toaster response." if wait_for_response && !customer_imap_configured?
    end

    def resolve_connection!
      relation = ImapConnection.all
      relation = relation.where(account_id: account_id) if account_id.present?
      relation = relation.where(id: connection_id) if connection_id.present?

      connection = relation.active_connections.first || relation.first
      return connection if connection

      raise Error, "No IMAP connection found for the provided account/connection filters."
    end

    def deliver_via_resend!(connection)
      delivery_method = Toaster::ResendDeliveryMethod.new(
        api_key: ENV.fetch("RESEND_API_KEY"),
        from: "#{from_name} <#{from_email}>"
      )
      delivery_method.deliver!(build_mail(connection))
    rescue KeyError
      raise Error, "RESEND_API_KEY must be set."
    rescue Toaster::ResendDeliveryMethod::DeliveryError => e
      raise Error, e.message
    end

    def build_mail(connection)
      current_subject = subject
      current_body = body

      Mail.new do
        from "#{from_name} <#{from_email}>"
        to connection.username
        subject current_subject
        text_part { body current_body }
      end
    end

    def wait_for_imap_receipt!(connection)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout_seconds

      Imap::Session.call(imap_connection: connection) do |imap|
        imap.select(connection.inbox_folder)

        loop do
          matched_uids = imap.search([ "HEADER", "SUBJECT", subject, "HEADER", "FROM", from_email ])
          return matched_uids if matched_uids.any?

          break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

          sleep poll_interval_seconds
        end
      end

      raise Error, "Timed out waiting for IMAP delivery after #{timeout_seconds}s for subject: #{subject.inspect}"
    end

    def wait_for_customer_response?(connection)
      wait_for_response || customer_imap_configured?
    end

    def customer_imap_configured?
      customer_imap_host.present? && customer_imap_username.present? && customer_imap_password.present?
    end

    def wait_for_customer_response!(connection)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout_seconds
      imap = begin
        session = Net::IMAP.new(customer_imap_host, port: customer_imap_port, ssl: customer_imap_ssl)
        session.login(customer_imap_username, customer_imap_password)
        session.select(customer_imap_inbox_folder)
        session
      rescue Net::IMAP::Error, SocketError, IOError => e
        raise Error, "Customer IMAP setup failed: #{e.message}"
      end

      loop do
        matched_uids = imap.search([ "HEADER", "SUBJECT", subject, "HEADER", "FROM", connection.username ])
        return matched_uids if matched_uids.any?

        break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

        sleep poll_interval_seconds
      end

      raise Error, "Timed out waiting for Toaster response after #{timeout_seconds}s for subject: #{subject.inspect}"
    rescue Net::IMAP::Error, SocketError, IOError => e
      raise Error, "Customer IMAP response check failed: #{e.message}"
    ensure
      begin
        imap&.disconnect
      rescue Net::IMAP::Error, IOError
        nil
      end
    end
  end
end
