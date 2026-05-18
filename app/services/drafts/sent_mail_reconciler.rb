require "net/imap"
require "mail"

module Drafts
  # Searches the IMAP Sent folder for a message that corresponds to a pushed
  # draft and classifies the outcome:
  #
  #   approved  — sent body is identical to the stored original_body
  #   modified  — sent body differs but similarity >= 50%
  #   rejected  — sent body differs and similarity < 50%, or draft was deleted
  #
  # Similarity is measured as a simple character-level ratio using the
  # longest-common-subsequence length over max(a, b) length, which is
  # sufficient for short email bodies without introducing gem dependencies.
  class SentMailReconciler
    MODIFIED_THRESHOLD = 0.50
    MAX_COMPARE_CHARS = 4000

    Result = Struct.new(:outcome, :sent_body, :similarity, keyword_init: true)

    def self.call(draft:, imap_connection:)
      new(draft, imap_connection).call
    end

    def initialize(draft, imap_connection)
      @draft = draft
      @imap_connection = imap_connection
    end

    def call
      Imap::Session.call(imap_connection: imap_connection) do |imap|
        folders = Imap::FolderLocator.call(imap: imap)
        return Result.new(outcome: :not_found) unless folders.sent_folder

        sent_body = find_sent_body(imap, folders.sent_folder)

        unless sent_body
          draft_still_exists = imap_draft_uid_exists?(imap, folders.drafts_folder)
          if draft_still_exists
            return Result.new(outcome: :pending, sent_body: nil, similarity: nil)
          else
            draft.update!(status: :rejected)
            return Result.new(outcome: :rejected, sent_body: nil, similarity: nil)
          end
        end

        similarity = body_similarity(draft.original_body.to_s, sent_body)
        outcome = classify(similarity)

        draft.update!(status: outcome, sent_at: Time.current)

        Result.new(outcome: outcome, sent_body: sent_body, similarity: similarity)
      end
    end

    private

    attr_reader :draft, :imap_connection

    def booking_request
      @booking_request ||= draft.booking_request
    end

    def conversation_thread
      @conversation_thread ||= booking_request.conversation_thread
    end

    def find_sent_body(imap, sent_folder)
      sent_body = nil

      imap.select(sent_folder)
      uids = search_sent_uids(imap)
      return nil if uids.empty?

      imap.uid_fetch(uids, %w[UID RFC822]).each do |msg|
        raw = msg.attr["RFC822"]
        next if raw.blank?
        mail = Mail.new(raw)
        body = extract_text(mail).to_s.strip
        next if body.empty?
        sent_body = body
        break
      end

      sent_body
    end

    def search_sent_uids(imap)
      thread_id = ConversationThreading.inbox_thread_id_from_canonical(conversation_thread.provider_thread_id)
      return [] if thread_id.blank?

      thread_id_bare = thread_id.gsub(/[<>]/, "")

      by_references = begin
        imap.uid_search([ "HEADER", "References", thread_id_bare ])
      rescue
        []
      end
      by_in_reply = begin
        imap.uid_search([ "HEADER", "In-Reply-To", thread_id_bare ])
      rescue
        []
      end
      (by_references + by_in_reply).uniq
    end

    def imap_draft_uid_exists?(imap, drafts_folder)
      return false unless draft.imap_draft_uid.present? && drafts_folder.present?

      imap.select(drafts_folder)
      result = begin
        imap.uid_fetch([ draft.imap_draft_uid ], "FLAGS")
      rescue
        nil
      end
      result.present?
    end

    def classify(similarity)
      if similarity >= 1.0
        :approved
      elsif similarity >= MODIFIED_THRESHOLD
        :modified
      else
        :rejected
      end
    end

    def body_similarity(original, sent)
      a = normalize(original)[0, MAX_COMPARE_CHARS]
      b = normalize(sent)[0, MAX_COMPARE_CHARS]
      return 1.0 if a == b
      return 0.0 if a.empty? && b.empty?
      return 0.0 if a.empty? || b.empty?

      lcs_length = lcs(a, b)
      lcs_length.to_f / [ a.length, b.length ].max
    end

    def normalize(text)
      text.to_s.gsub(/\s+/, " ").strip.downcase
    end

    # Computes LCS length using a space-efficient two-row DP approach.
    def lcs(a, b)
      a_chars = a.chars
      b_chars = b.chars
      prev = Array.new(b_chars.length + 1, 0)

      a_chars.each do |ca|
        curr = Array.new(b_chars.length + 1, 0)
        b_chars.each_with_index do |cb, j|
          curr[j + 1] = if ca == cb
            prev[j] + 1
          else
            [ curr[j], prev[j + 1] ].max
          end
        end
        prev = curr
      end

      prev.last
    end

    def extract_text(mail)
      if mail.multipart?
        part = mail.text_part
        part ? part.body.decoded.force_encoding("UTF-8").scrub : nil
      elsif mail.content_type&.include?("text/plain")
        mail.body.decoded.force_encoding("UTF-8").scrub
      end
    end
  end
end
