# frozen_string_literal: true

module Ops
  class ActivityFeed
    Row = Data.define(:account_id, :provider, :kind, :provider_thread_id, :anchor_inbox_message_id, :last_activity_at)

    MESSAGE_SCAN_LIMIT = 400

    def self.call(limit: 50)
      new(limit: limit).call
    end

    def initialize(limit: 50)
      @limit = limit
    end

    def call
      recent = InboxMessage
        .order(Arel.sql("COALESCE(received_at, created_at) DESC"))
        .limit(MESSAGE_SCAN_LIMIT)
        .to_a

      buckets = Hash.new { |h, k| h[k] = [] }
      recent.each { |m| buckets[thread_key_for(m)] << m }

      activity = {}
      buckets.each_key do |key|
        msgs = buckets[key]
        activity[key] = msgs.map { |m| message_activity_ts(m) }.max
      end

      merge_draft_peaks!(activity)

      sorted_keys = activity.sort_by { |_, t| -t.to_f }.first(@limit).map(&:first)

      sorted_keys.map { |key| build_row(key, activity[key]) }
    end

    private

    def thread_key_for(message)
      if message.provider_thread_id.present?
        [ :thread, message.account_id, message.provider, message.provider_thread_id ]
      else
        [ :singleton, message.account_id, message.provider, message.id ]
      end
    end

    def message_activity_ts(message)
      message.received_at || message.created_at
    end

    def merge_draft_peaks!(activity)
      connection = ActiveRecord::Base.connection

      connection.select_all(draft_peaks_thread_sql).each do |row|
        key = [ :thread, row["account_id"].to_i, row["provider"], row["provider_thread_id"] ]
        peak = parse_sql_time(row["peak"])
        activity[key] = [ activity[key], peak ].compact.max
      end

      connection.select_all(draft_peaks_singleton_sql).each do |row|
        key = [ :singleton, row["account_id"].to_i, row["provider"], row["anchor_id"].to_i ]
        peak = parse_sql_time(row["peak"])
        activity[key] = [ activity[key], peak ].compact.max
      end
    end

    def draft_peaks_thread_sql
      <<~SQL.squish
        SELECT booking_requests.account_id,
               inbox_messages.provider,
               conversation_threads.provider_thread_id,
               MAX(CASE
                 WHEN drafts.status = 'sent' THEN COALESCE(drafts.sent_at, drafts.updated_at)
                 ELSE drafts.created_at
               END) AS peak
        FROM drafts
        INNER JOIN booking_requests ON booking_requests.id = drafts.booking_request_id
        INNER JOIN conversation_threads ON conversation_threads.id = booking_requests.conversation_thread_id
        INNER JOIN inbox_messages ON inbox_messages.id = booking_requests.source_inbox_message_id
        WHERE conversation_threads.provider_thread_id IS NOT NULL
        GROUP BY booking_requests.account_id, inbox_messages.provider, conversation_threads.provider_thread_id
      SQL
    end

    def draft_peaks_singleton_sql
      <<~SQL.squish
        SELECT booking_requests.account_id,
               inbox_messages.provider,
               inbox_messages.id AS anchor_id,
               MAX(CASE
                 WHEN drafts.status = 'sent' THEN COALESCE(drafts.sent_at, drafts.updated_at)
                 ELSE drafts.created_at
               END) AS peak
        FROM drafts
        INNER JOIN booking_requests ON booking_requests.id = drafts.booking_request_id
        INNER JOIN inbox_messages ON inbox_messages.id = booking_requests.source_inbox_message_id
        WHERE inbox_messages.provider_thread_id IS NULL
        GROUP BY booking_requests.account_id, inbox_messages.provider, inbox_messages.id
      SQL
    end

    def parse_sql_time(value)
      return nil if value.blank?

      Time.zone.parse(value.to_s)
    end

    def build_row(key, last_activity_at)
      kind = (key[0] == :singleton) ? "singleton" : "thread"
      Row.new(
        account_id: key[1],
        provider: key[2],
        kind: kind,
        provider_thread_id: (key[0] == :thread) ? key[3] : nil,
        anchor_inbox_message_id: (key[0] == :singleton) ? key[3] : nil,
        last_activity_at: last_activity_at
      )
    end
  end
end
