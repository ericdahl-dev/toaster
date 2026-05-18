# frozen_string_literal: true

require "net/smtp"
require "mail"

module Drafts
  # Sends a Draft via SMTP using the credentials of an ImapConnection.
  # Marks the draft as sent on success. Raises SendError on delivery failure.
  class SmtpSender
    class SendError < StandardError; end

    DEFAULT_SMTP_PORT = 587

    SMTP_ERRORS = [
      Net::SMTPAuthenticationError,
      Net::SMTPServerBusy,
      Net::SMTPSyntaxError,
      Net::SMTPFatalError,
      Net::SMTPUnknownError,
      Errno::ECONNREFUSED,
      Errno::ETIMEDOUT,
      SocketError
    ].freeze

    def self.call(draft:, imap_connection:)
      new(draft: draft, imap_connection: imap_connection).call
    end

    def initialize(draft:, imap_connection:)
      @draft = draft
      @imap_connection = imap_connection
    end

    def call
      mail = build_mail
      mail.deliver!
      draft.update!(status: :sent, sent_at: Time.current)
    rescue *SMTP_ERRORS => e
      raise SendError, "SMTP delivery failed: #{e.message}"
    end

    def effective_smtp_host
      return imap_connection.smtp_host if imap_connection.smtp_host.present?

      host = imap_connection.host
      host.start_with?("imap.") ? host.sub("imap.", "smtp.") : host
    end

    def effective_smtp_port
      imap_connection.smtp_port.presence || DEFAULT_SMTP_PORT
    end

    private

    attr_reader :draft, :imap_connection

    def booking_request
      @booking_request ||= draft.booking_request
    end

    def conversation_thread
      @conversation_thread ||= booking_request.conversation_thread
    end

    def to_address
      booking_request.contact.email
    end

    def subject_line
      Drafts::MailBuilder.new(draft: draft).subject_line
    end

    def build_mail
      smtp_host = effective_smtp_host
      smtp_port = effective_smtp_port
      username = imap_connection.username
      password = imap_connection.password
      use_ssl = smtp_port == 465

      mail = Mail.new
      mail.from = username
      mail.to = to_address
      mail.subject = subject_line
      mail.body = draft.body
      header_thread_id = ConversationThreading.inbox_thread_id_from_canonical(conversation_thread.provider_thread_id)
      if header_thread_id.present?
        mail.in_reply_to = header_thread_id
        mail.references = header_thread_id
      end

      mail.delivery_method :smtp, {
        address: smtp_host,
        port: smtp_port,
        user_name: username,
        password: password,
        authentication: :plain,
        enable_starttls_auto: !use_ssl,
        ssl: use_ssl
      }

      mail
    end
  end
end
