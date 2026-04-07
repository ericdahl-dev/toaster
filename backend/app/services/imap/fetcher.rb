require "net/imap"
require "mail"

module Imap
  class Fetcher
    class Error < StandardError; end

    FETCH_ATTRIBUTES = %w[UID RFC822 ENVELOPE].freeze

    def initialize(imap_connection:)
      @imap_connection = imap_connection
    end

    def fetch_messages
      validate_config!

      messages = []

      with_imap do |imap|
        imap.select(imap_connection.inbox_folder)

        uids = search_uids(imap)
        return messages if uids.empty?

        imap.uid_fetch(uids, FETCH_ATTRIBUTES).each do |msg|
          normalized = normalize_message(msg)
          messages << normalized if normalized
        end
      end

      messages
    end

    private

    attr_reader :imap_connection

    def with_imap
      imap = Net::IMAP.new(
        imap_connection.host,
        port: imap_connection.port,
        ssl: imap_connection.ssl?
      )
      imap.login(imap_connection.username, imap_connection.password)
      yield imap
    ensure
      imap&.disconnect rescue nil
    end

    def search_uids(imap)
      if imap_connection.last_synced_uid.present?
        imap.uid_search([ "UID", "#{imap_connection.last_synced_uid + 1}:*" ])
      else
        imap.uid_search([ "ALL" ])
      end
    end

    def normalize_message(msg)
      uid = msg.attr["UID"]
      return nil unless uid

      raw = msg.attr["RFC822"]
      return nil if raw.blank?

      mail = Mail.new(raw)

      from_addr = mail[:from]&.addrs&.first
      from_name = from_addr&.display_name
      from_email = from_addr&.address

      to_emails = Array(mail[:to]&.addrs).filter_map(&:address)

      message_id = mail.message_id.presence || "uid:#{imap_connection.id}:#{uid}"
      thread_id = mail.references&.first || mail.in_reply_to || message_id

      {
        provider: "imap",
        provider_message_id: message_id,
        provider_thread_id: thread_id,
        direction: "inbound",
        from_name: from_name,
        from_email: from_email,
        to_emails: to_emails,
        subject: mail.subject,
        body_text: extract_text(mail),
        body_html: extract_html(mail),
        received_at: mail.date&.to_time,
        raw_payload: { "uid" => uid, "message_id" => message_id }
      }
    end

    def parse_address(value)
      return [ nil, nil ] if value.blank?

      match = value.to_s.match(/\A(?:(.+?)\s*<)?([^<>@\s]+@[^<>@\s]+)>?\z/)
      return [ nil, value.to_s ] unless match

      [ match[1]&.strip, match[2] ]
    end

    def extract_text(mail)
      if mail.multipart?
        part = mail.text_part
        part ? decode_part(part) : nil
      elsif mail.content_type&.include?("text/plain")
        decode_part(mail)
      end
    end

    def extract_html(mail)
      if mail.multipart?
        part = mail.html_part
        part ? decode_part(part) : nil
      elsif mail.content_type&.include?("text/html")
        decode_part(mail)
      end
    end

    def decode_part(part)
      part.body.decoded.force_encoding("UTF-8").scrub
    rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
      part.body.decoded.encode("UTF-8", invalid: :replace, undef: :replace)
    end

    def validate_config!
      raise Error, "IMAP host is not set" if imap_connection.host.blank?
      raise Error, "IMAP username is not set" if imap_connection.username.blank?
      raise Error, "IMAP password is not set" if imap_connection.password.blank?
    end
  end
end
