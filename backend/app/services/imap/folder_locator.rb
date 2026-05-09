require "net/imap"

module Imap
  # Discovers the Drafts and Sent special-use folders for an IMAP connection.
  #
  # Tries RFC 6154 LIST-EXTENDED special-use attributes first, then falls back
  # to a ranked list of common folder names so the result is provider-agnostic.
  #
  # Can be called with an already-open imap object to share a session:
  #   Imap::FolderLocator.call(imap: open_imap_object)
  # Or with a connection to open its own session:
  #   Imap::FolderLocator.call(imap_connection: connection)
  class FolderLocator
    DRAFTS_FALLBACKS = %w[Drafts Draft [Gmail]/Drafts INBOX.Drafts].freeze
    SENT_FALLBACKS = %w[Sent "Sent Items" "Sent Mail" [Gmail]/Sent\ Mail INBOX.Sent].freeze

    Result = Struct.new(:drafts_folder, :sent_folder, keyword_init: true)

    def self.call(imap_connection: nil, imap: nil)
      new(imap_connection: imap_connection, imap: imap).call
    end

    def initialize(imap_connection: nil, imap: nil)
      @imap_connection = imap_connection
      @open_imap = imap
    end

    def call
      if @open_imap
        locate(@open_imap)
      else
        Imap::Session.call(imap_connection: @imap_connection) do |imap|
          locate(imap)
        end
      end
    end

    private

    def locate(imap)
      all_folders = list_all_folders(imap)
      drafts = find_by_special_use(imap, "\\Drafts") || find_by_name(all_folders, DRAFTS_FALLBACKS)
      sent = find_by_special_use(imap, "\\Sent") || find_by_name(all_folders, SENT_FALLBACKS)
      Result.new(drafts_folder: drafts, sent_folder: sent)
    end

    def list_all_folders(imap)
      imap.list("", "*") || []
    end

    def find_by_special_use(imap, attribute)
      mailboxes = begin
        imap.list("", "*", return: [ "SPECIAL-USE" ])
      rescue
        nil
      end
      return nil unless mailboxes

      match = mailboxes.find do |mb|
        Array(mb.attr).any? { |a| a.to_s.casecmp(attribute).zero? }
      end
      match&.name
    end

    def find_by_name(all_folders, candidates)
      folder_names = all_folders.map(&:name)
      candidates.find { |candidate| folder_names.any? { |f| f.casecmp(candidate).zero? } }
    end
  end
end
