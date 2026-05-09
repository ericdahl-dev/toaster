require "net/imap"
require "mail"

module Drafts
  # Appends a Draft record's body as a \Draft-flagged message to the IMAP
  # Drafts folder, then persists the resulting UID and original_body on the
  # Draft record so the reconciler can later compare against the sent copy.
  class ImapDraftPusher
    class Error < StandardError; end
    class FolderNotFound < Error; end

    def self.call(draft:, imap_connection:)
      new(draft, imap_connection).call
    end

    def initialize(draft, imap_connection)
      @draft = draft
      @imap_connection = imap_connection
    end

    def call
      raw = build_raw_message
      uid = nil

      Imap::Session.call(imap_connection: imap_connection) do |imap|
        folders = Imap::FolderLocator.call(imap: imap)
        raise FolderNotFound, "Could not locate Drafts folder on #{imap_connection.host}" unless folders.drafts_folder

        imap.select(folders.drafts_folder)
        imap.append(folders.drafts_folder, raw, [ :Draft ], Time.current)
        uids = imap.uid_search([ "HEADER", "Message-ID", message_id ])
        uid = uids.last
      end

      draft.update!(
        imap_draft_uid: uid,
        original_body: draft.body
      )

      uid
    end

    private

    attr_reader :draft, :imap_connection

    def message_id
      @message_id ||= "<draft-#{draft.id}-#{SecureRandom.hex(8)}@toaster>"
    end

    def booking_request
      @booking_request ||= draft.booking_request
    end

    def conversation_thread
      @conversation_thread ||= booking_request.conversation_thread
    end

    def build_raw_message
      mail = Mail.new
      mail["Message-ID"] = message_id
      mail.in_reply_to = conversation_thread.provider_thread_id if conversation_thread.provider_thread_id.present?
      mail.references = conversation_thread.provider_thread_id if conversation_thread.provider_thread_id.present?
      mail.from = imap_connection.username
      mail.subject = derive_subject
      mail.body = draft.body
      mail.to_s
    end

    def derive_subject
      last_subject = booking_request.source_inbox_message&.subject
      return "Re: #{last_subject}" if last_subject.present? && !last_subject.start_with?("Re:")
      last_subject.presence || "Re: your inquiry"
    end
  end
end
